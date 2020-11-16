# encoding: utf-8
module Helpdesk::SendAndSetHelper
  #Any changes made in this file should be replicated in conversations_controller, tickets_controller and notes/callback if required

  include Redis::RedisKeys
  include AdvancedTicketScopes

  def self.included(base)
    base.send :before_filter, :set_mobile, :set_native_mobile, :load_ticket_item, :handle_send_and_set, :verify_permission, :build_note_body_attributes, :build_conversation_for_ticket, :check_for_from_email, :kbase_email_included,
                  :set_default_source, :prepare_mobile_note_for_send_set, :fetch_note_attachments, :traffic_cop_warning, 
                  :check_for_public_notes, :check_reply_trial_customers_limit, :only => :send_and_set_status
  end

  def build_note_body_attributes
    #might be redundant
    if params[:helpdesk_note][:body] || params[:helpdesk_note][:body_html]
      unless params[:helpdesk_note].has_key?(:note_body_attributes)
        note_body_hash = {:note_body_attributes => { :body => params[:helpdesk_note][:body],
                                :body_html => params[:helpdesk_note][:body_html] }}
        params[:helpdesk_note].merge!(note_body_hash).tap do |t|
          t.delete(:body) if t[:body]
          t.delete(:body_html) if t[:body_html]
        end
      end
    end
  end

  def build_conversation_for_ticket
    @note = @ticket.notes.build(params[:helpdesk_note])
    @note.send_survey = params[:send_survey]
    @note.include_surveymonkey_link = params[:include_surveymonkey_link]
    @note.user ||= current_user if current_user
    @note.changes_for_observer = {}
  end

  def load_ticket_item
    @ticket = @item = load_by_param(params[:id])
    load_or_show_error
  end

  def check_for_from_email
    if @note.source == Account.current.helpdesk_sources.note_source_keys_by_token["email"] and @note.from_email.present? and !current_account.support_emails_in_downcase.include?(parse_email_text(@note.from_email)[:email])
      flash[:notice] = I18n.t('ticket.errors.request_dropped')
      logger.debug "From email in request doesn't match with supported emails for the account #{current_account.id} for ticket #{@note.notable.id} with display_id #{@note.notable.display_id}, had the from email #{@note.from_email}"
      @scroll_to_top = true
      create_error
    end
  end

  def set_quoted_text
    @note.quoted_text = params[:quoted_text].present? && params[:quoted_text] == 'true' if is_reply?
  end

  def load_or_show_error(load_notes = false)
    return redirect_to support_ticket_url(@ticket) if @ticket and current_user.customer?
    if @ticket 
      return helpdesk_restricted_access_redirection(@ticket, 'flash.agent_as_requester.ticket_show') if @ticket.restricted_in_helpdesk?(current_user)
      has_permission = (advanced_scope_enabled? && action == :print) ? current_user.has_read_ticket_permission?(@ticket) : current_user.has_ticket_permission?(@ticket) if current_user
      return helpdesk_restricted_access_redirection(@ticket, nil, t("flash.general.access_denied").html_safe) unless current_user && has_permission && !@ticket.trashed
    end
    load_archive_ticket(load_notes) unless @ticket
  end

  def load_archive_ticket(load_notes = false)
    raise ActiveRecord::RecordNotFound unless current_account.features_included?(:archive_tickets)

    options = load_notes ? archive_preload_options : {}
    archive_ticket = load_by_param(params[:id], options, true)
    raise ActiveRecord::RecordNotFound unless archive_ticket

    # Temporary fix to redirect /helpdesk URLs to /support for archived tickets
    if current_user.customer?
      redirect_to support_archive_ticket_path(params[:id])
    elsif archive_ticket.restricted_in_helpdesk?(current_user)
      helpdesk_restricted_access_redirection(archive_ticket, 'flash.agent_as_requester.ticket_show')
    else
      redirect_to helpdesk_archive_ticket_path(params[:id])
    end
  end

  def enqueue_send_set_observer
    note_params = { :id => @note.id,
                    :model_changes => @note.changes_for_observer,
                    :freshdesk_webhook => @note.freshdesk_webhook?,
                    :current_user_id => @note.user_id,
                    :send_and_set => true
    }
    args = {
      :ticket_changes => @ticket.observer_args,
      :note_changes => note_params
    }
    if @ticket.schedule_observer
      job_id = ::Tickets::SendAndSetWorker.perform_async(args)
      Va::Logger::Automation.set_thread_variables(current_account.id, @note.notable_id, @note.user_id)
      Va::Logger::Automation.log("Triggering SendAndSetWorker, job_id=#{job_id}, info=#{args.inspect}", true)
      Va::Logger::Automation.unset_thread_variables
    end
  end

  def set_default_source
    @note.source = Account.current.helpdesk_sources.note_source_keys_by_token["note"] if params[:helpdesk_note][:source].blank?
  end

  def kbase_email_included
    kbase_email = current_account.kbase_email
    if @note.source == Account.current.helpdesk_sources.note_source_keys_by_token["email"] and (params[:helpdesk_note].slice(*[:to_emails, :cc_emails, :bcc_emails]).values.flatten.include?(kbase_email))
      @note.bcc_emails.delete(kbase_email)
      @note.cc_emails.delete(kbase_email)
      @note.instance_variable_set(:@create_solution_privilege, privilege?(:publish_solution))
    end
  end

  def has_unseen_notes?
    return false if params["last_note_id"].nil?
    last_public_note    = @ticket.notes.conversations(nil, 'created_at DESC', 1).first
    late_public_note_id = last_public_note.blank? ? -1 : last_public_note.id
    return late_public_note_id > params["last_note_id"].to_i
  end

  def traffic_cop_warning
    return unless traffic_cop_feature_enabled? and has_unseen_notes?
    @notes = @ticket.conversation_since(params[:since_id]).reverse
    @public_notes = @notes.select{ |note| note.private == false || note.incoming == true }
    @parent ||= @ticket
    respond_to do |format|
      format.js {
        render :file => "helpdesk/notes/traffic_cop.rjs" and return true
      }
    end
  end

  def check_for_public_notes
    return unless traffic_cop_feature_enabled? and @note.source == Account.current.helpdesk_sources.note_source_keys_by_token["note"]
    traffic_cop_warning unless params[:helpdesk_note][:private].to_s.to_bool
  end

  def check_reply_trial_customers_limit
    return unless @note.source == Account.current.helpdesk_sources.note_source_keys_by_token["email"]
    if ((current_account.id > get_spam_account_id_threshold) && (!ismember?(SPAM_WHITELISTED_ACCOUNTS, current_account.id)))
      if current_account.subscription.trial? && max_to_cc_threshold_crossed?
        respond_to do |format|
          format.js { render :file => "helpdesk/notes/inline_error.rjs", :locals => { :msg => t(:'flash.general.recipient_limit_exceeded', :limit => get_trial_account_max_to_cc_threshold )} }
        end
      elsif(account_created_recently? && (current_account.email_configs.count == 1) && (current_account.email_configs[0].reply_email.end_with?(current_account.full_domain)) && max_to_cc_threshold_crossed?)
        FreshdeskErrorsMailer.error_email(nil, {:domain_name => current_account.full_domain}, nil, {
          :subject => "Maximum thread to, cc, bcc threshold crossed for Account :#{current_account.id} ",
          :recipients => ["mail-alerts@freshdesk.com", "noc@freshdesk.com","helpdesk@noc-alerts.freshservice.com"],
          :additional_info => {:info => "Please check spam activity in Ticket : #{@ticket.id}"}
          })
      end
    end
  end

  def max_to_cc_threshold_crossed?
    note_cc_email = get_email_array(@note.cc_emails_hash[:cc_emails])
    note_to_email = get_email_array(@note.to_emails)
    note_bcc_email = get_email_array(@note.bcc_emails)
    ticket_from_email = get_email_array(@ticket.from_email)
    cc_email_hash = @ticket.cc_email_hash.nil? ? Helpdesk::Ticket.default_cc_hash : @ticket.cc_email_hash

    bcc_emails = get_email_array(cc_email_hash[:bcc_emails])
    cc_emails = get_email_array(cc_email_hash[:cc_emails])
    fwd_emails = get_email_array(cc_email_hash[:fwd_emails])

    old_recipients = bcc_emails.present? ? (cc_emails | fwd_emails | ticket_from_email | bcc_emails) : (cc_emails | fwd_emails | ticket_from_email)
    total_recipients = old_recipients | note_cc_email | note_to_email | note_bcc_email

    return (total_recipients.count != old_recipients.count ) && (total_recipients.count) > get_trial_account_max_to_cc_threshold
  end


  def traffic_cop_feature_enabled?
    current_account.traffic_cop_enabled?
  end

  def fetch_note_attachments
    return unless @note
    if params[:sol_articles_cloud_file_attachments].present?
      fetch_cloud_file_attachments @note
    end
    (params[:helpdesk_note][:attachments] || []).each do |a|
      fetch_item_attcachments_using_id a
    end
  end

  def clear_saved_draft
    remove_tickets_redis_key(HELPDESK_REPLY_DRAFTS % { 
                                :account_id => current_account.id, 
                                :user_id => current_user.id, 
                                :ticket_id => @ticket.id
                            })
  end

  def note_to_kbase
    begin
      create_article if @note.instance_variable_get(:@create_solution_privilege)
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
    end
  end

  def create_article
    body_html = params[:helpdesk_note][:note_body_attributes][:full_text_html]
    attachments = params[:helpdesk_note][:attachments]
    Helpdesk::KbaseArticles.create_article_from_note(current_account, current_user, @ticket.subject, body_html, attachments)
  end

  def process_and_redirect
    Thread.current[:notifications] = current_account.email_notifications
    options = {}
    options.merge!({:human=>true}) if(!params[:human].blank? && params[:human].to_s.eql?("true"))  #to avoid unneccesary queries to users
    url_redirect = params[:redirect_to].present? ? TICKET_REDIRECT_MAPPINGS[params[:redirect_to]] : item_url
    @send_and_set_response = { :success => true, :redirect => (params[:redirect] && params[:redirect].to_bool) }
    @send_and_set_response.merge!(:autoplay_link => autoplay_link) if @ticket.trigger_autoplay?
    @send_and_set_response.merge!(:err_msg => @status_err_msg) unless @status_err_msg.nil?
    respond_to do |format|
      format.js {
        update_activities
        render :file => "helpdesk/notes/create.rjs"
      }
    end

  ensure
    Thread.current[:notifications] = nil
  end

  def flash_message(result)
    if @note.broadcast_note? && result == 'success'
      flash[:notice] = t(:"flash.tickets.notes.broadcast.#{result}", :count => @ticket.related_tickets_count)
    else
      flash[:notice] ||= I18n.t(:"flash.tickets.notes.send_and_set.#{result}")
    end
  end

  def prepare_mobile_note_for_send_set
    prepare_mobile_note @note
  end

  def update_activities
    if params[:showing] == 'activities'
      type = :tkt_activity
      params[:limit] = ActivityConstants::QUERY_UI_LIMIT
      params[:event_type] = ::HelpdeskActivities::EventType::ALL
      @activities_data = new_activities(params, @ticket, type)
       if  @activities_data[:activity_list].present?
        @activities = @activities_data[:activity_list].reverse
      end
    end
  end

  def is_reply?
    @note and @note.source == Account.current.helpdesk_sources.note_source_keys_by_token["email"]
  end

  def create_error(note_type = nil)
    respond_to do |format|
      format.js { render :file => "helpdesk/notes/error.rjs", :locals => { :note_type => note_type} }
    end
  end
end
