class Helpdesk::ConversationsController < ApplicationController

  require 'freemail'

  helper  Helpdesk::TicketsHelper#TODO-RAILS3
  
  before_filter :load_parent_ticket_or_issue
  
  include HelpdeskControllerMethods
  include ParserUtil
  include Conversations::Email
  include Conversations::Twitter
  include Facebook::TicketActions::Util
  include Helpdesk::Activities
  include Helpdesk::Activities::ActivityMethods
  include Helpdesk::Permissible
  include Redis::RedisKeys
  include Redis::TicketsRedis
  include Social::Util
  helper Helpdesk::NotesHelper
  include Ecommerce::Ebay::ReplyHelper
  include Helpdesk::SpamAccountConstants
  include Redis::OthersRedis
  include EmailHelper
  
  # Send and set status is handled separately in the tickets_controller.
  # Any changes related to note or reply made in this file should be replicated in 
  # send_and_set_helper as well
  before_filter :build_note_body_attributes, :build_conversation, :except => [:full_text, :traffic_cop]
  before_filter :check_for_from_email, :only => [:reply, :forward, :reply_to_forward]
  before_filter :validate_tkt_type, :only => :broadcast
  before_filter :validate_fwd_to_email, :only => [:forward, :reply_to_forward]
  before_filter :check_for_kbase_email, :only => [:reply, :forward]
  before_filter :set_quoted_text, :only => :reply
  before_filter :set_default_source, :set_mobile, :prepare_mobile_note,
    :fetch_item_attachments, :set_native_mobile, :except => [:full_text, :traffic_cop]
  before_filter :set_ticket_status, :except => [:forward, :reply_to_forward, :traffic_cop]
  before_filter :load_item, :only => [:full_text]
  before_filter :verify_permission, :only => [:reply, :forward, :reply_to_forward, :note, :twitter,
   :facebook, :mobihelp, :ecommerce, :traffic_cop, :full_text, :broadcast]
  before_filter :traffic_cop_warning, :if => :traffic_cop_feature_enabled?, :only => [:reply, :twitter, :facebook, :mobihelp, :ecommerce]
  before_filter :check_for_public_notes, :if => :traffic_cop_feature_enabled?, :only => [:note]
  before_filter :check_trial_customers_limit, :only => [:reply, :forward, :reply_to_forward]
  before_filter :validate_ecommerce_reply, :only => :ecommerce
  around_filter :run_on_slave, :only => [:update_activities, :has_unseen_notes, :traffic_cop_warning]
  before_filter :validate_facebook_dm_reply, :only => [:facebook]

  TICKET_REDIRECT_MAPPINGS = {
    "helpdesk_ticket_index" => "/helpdesk/tickets"
  }
    
  def reply
    # Any changes related to note or reply made in this file should be replicated in 
    # send_and_set_helper if required
    build_attachments @item, :helpdesk_note
    @item.send_survey = params[:send_survey]
    @item.include_surveymonkey_link = params[:include_surveymonkey_link]
    learn_valid_ticket_data
    if @item.save_note
      clear_saved_draft
      @parent.add_forum_post(@item) if params[:post_forums]
      note_to_kbase
      flash[:notice] = t(:'flash.tickets.reply.success')
      process_and_redirect
    else
      flash[:error] = @item.errors.full_messages.to_sentence 
      create_error(:reply)
    end
  end
  
  def forward
    build_attachments @item, :helpdesk_note
    if @item.save_note
      @parent.add_forum_post(@item) if params[:post_forums]
      note_to_kbase
      flash[:notice] = t(:'fwd_success_msg')
      process_and_redirect
    else
      flash[:error] = @item.errors.full_messages.to_sentence 
      create_error(:fwd)
    end
  end

  def reply_to_forward
    build_attachments @item, :helpdesk_note
    if @item.save_note
      @parent.add_forum_post(@item) if params[:post_forums]
      flash[:notice] = t(:'fwd_success_msg')
      process_and_redirect
    else
      flash[:error] = @item.errors.full_messages.to_sentence 
      create_error(:fwd)
    end

  end

  def note
    # Any changes related to note or reply made in this file should be replicated in 
    # send_and_set_helper if required
    build_attachments @item, :helpdesk_note
    if @item.save_note
      flash_message "success"
      process_and_redirect
    else
      flash_message "failure"
      create_error(:note)
    end
  end

  def twitter
    tweet_text = params[:helpdesk_note][:note_body_attributes][:body].strip
    twt_type = Social::Tweet::TWEET_TYPES.rassoc(params[:tweet_type].to_sym) ? params[:tweet_type] : 'mention'
    twitter_handle_id = params[:twitter_handle]
    error_message, @tweet_body = get_tweet_text(twt_type, @parent, tweet_text)
    reply_handle_id = twitter_handle_id || @parent.fetch_twitter_handle
    reply_handle = current_account.twitter_handles.find_by_id(reply_handle_id)
    if reply_handle.blank?
      error_message = (I18n.t('social.streams.twitter.feeds_blank')).to_s
    elsif reply_handle.reauth_required?
      error_message = (I18n.t('social.streams.twitter.handle_auth_error')).to_s
    end
    if error_message.blank?
      stream = fetch_stream(reply_handle, @parent, twt_type)
      custom_twitter_stream_tweet_reply = custom_twitter_stream_tweet_reply?(stream, twt_type)
      unless custom_twitter_stream_tweet_reply
        stream_id = stream.id
        tweet_id = random_tweet_id
        @item.build_tweet(tweet_id: tweet_id,
                          tweet_type: twt_type,
                          twitter_handle_id: reply_handle_id, stream_id: stream_id)
      end
      if @item.save_note
        args = { ticket_id: @parent.id, note_id: @item.id, tweet_type: twt_type, twitter_handle_id: twitter_handle_id }
        Social::TwitterReplyWorker.perform_async(args) if custom_twitter_stream_tweet_reply
        flash.now[:notice] = t(:'flash.tickets.reply.success')
        process_and_redirect
      else
        flash.now[:notice] = t(:'flash.tickets.reply.failure')
        create_error(:twitter)
      end
    else
      flash[:error] = error_message
      create_error(:twitter)
    end
  end

  def facebook
    error_message = check_fb_page_validity
    if error_message.blank?
      if @item.save_note
        send_facebook_reply(params[:parent_post])
        process_and_redirect
      else
        # Flash here
        flash[:error] = 'failure'
        create_error(:facebook)
      end
    else
      flash[:error] = error_message
      create_error(:facebook)
    end
  end
  
  def mobihelp
    if @item.save_note
      flash[:notice] = t(:'flash.tickets.reply.success') 
      process_and_redirect
    else
      create_error
    end
  end

  def ecommerce
    ebay_reply 
  end

  def full_text
    render :text => @item.full_text_html.to_s.html_safe
  end

  def traffic_cop
    return if traffic_cop_warning
    respond_to do |format|
      format.js {
        render  :nothing => true
      }
    end
  end

  def broadcast
    if @item.save_note
      flash_message "success"
      process_and_redirect
    else
      flash_message "failure"
      create_error(:note)
    end
  end

  protected

    def check_fb_page_validity
      fb_page = @parent.fb_post.present? ? @parent.fb_post.facebook_page : nil
      return I18n.t('social.streams.facebook_pages.engage_info.add_facebook').to_s if fb_page.blank?

      fb_page.reauth_required? ? I18n.t('reauthorize_facebook').to_s : nil
    end

    def verify_permission
      verify_ticket_permission(@parent)
    end

    def build_note_body_attributes
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
    
    def build_conversation
      logger.debug "testing the caller class:: #{nscname} and cname::#{cname}"
      @item = self.instance_variable_set('@' + cname, scoper.build(params[nscname]))
      # TODO-RAILS3 need think another better way
      @item.notable = @parent
      set_item_user
      @item
    end

    def check_for_from_email
      if @item.from_email.present? and !current_account.support_emails_in_downcase.include?(parse_email_text(@item.from_email)[:email])
        flash[:notice] = I18n.t('ticket.errors.request_dropped')
        logger.debug "From email in request doesn't match with supported emails for the account #{current_account.id} for ticket #{@item.notable.id} with display_id #{@item.notable.display_id}, had the from email #{@item.from_email}"
        @scroll_to_top = true
        create_error 
      end
    end

    def validate_tkt_type
      create_error(:note) unless @parent.tracker_ticket?
    end

    def cname
      @cname = "note"
    end

    def nscname
      @nscname = "helpdesk_note"
    end

    def scoper
      @parent.notes
    end

    def item_url
      if @parent.is_a?(Helpdesk::Ticket) && !params[:page].nil?
        helpdesk_ticket_path({:id=> @parent.display_id, :page =>  params[:page]})
      else
        @parent
      end
    end
    
    def set_default_source
      @item.source = current_account.helpdesk_sources.note_source_keys_by_token["note"] if params[:helpdesk_note][:source].blank?
    end

    def after_restore_url
      :back
    end

    def process_and_redirect
      Thread.current[:notifications] = current_account.email_notifications
      options = {}
      options.merge!({:human=>true}) if(!params[:human].blank? && params[:human].to_s.eql?("true"))  #to avoid unneccesary queries to users
      url_redirect = params[:redirect_to].present? ? TICKET_REDIRECT_MAPPINGS[params[:redirect_to]] : item_url
      
      respond_to do |format|
        format.html { redirect_to url_redirect }
        format.xml  { render :xml => @item.to_xml(options), :status => :created, :location => url_for(@item) }
        format.json { render :json => @item.to_json(options) }
        format.js { 
          update_activities
          render :file => "helpdesk/notes/create.rjs" 
        }
        format.mobile {
          render :json => {:success => true,:item => @item}.to_json
        }
        format.nmobile {
            render :json => {:server_response => true}.to_json
        }
      end
      
    ensure
      Thread.current[:notifications] = nil
    end

    def create_error(note_type = nil)
      respond_to do |format|
        format.js { render :file => "helpdesk/notes/error.rjs", :locals => { :note_type => note_type} }
        format.html { redirect_to @parent }
        format.nmobile { render :json => { :server_response => false } }
        format.any(:json, :xml) { render request.format.to_sym => @item.errors, :status => 400 }
      end
    end
    
    private

      def traffic_cop_feature_enabled?
        current_account.traffic_cop_enabled?
      end

      def validate_facebook_dm_reply
        @item.body.gsub!(NEW_LINE_WITH_CARRIAGE_RETURN, NEW_LINE_CHARACTER)
        create_error(:facebook) if @item.notable.facebook_realtime_message? and @item.body.length > Facebook::Constants::REALTIME_MESSSAGING_CHARACTER_LIMIT
      end
      
      def set_quoted_text
        @item.quoted_text = params[:quoted_text].present? && params[:quoted_text] == 'true'
      end
      
      def set_ticket_status
        if privilege?(:edit_ticket_properties) && !params[:ticket_status].blank?
          @item.notable.status = params[:ticket_status]
          Thread.current[:notifications] = current_account.email_notifications
          Thread.current[:notifications][EmailNotification::TICKET_RESOLVED][:requester_notification] = false
        end
      end
      
      def update_activities
        if params[:showing] == 'activities'
          type = :tkt_activity
          params[:limit] = ActivityConstants::QUERY_UI_LIMIT
          params[:event_type] = ::HelpdeskActivities::EventType::ALL
          @activities_data = new_activities(params, @item.notable, type)
           if  @activities_data[:activity_list].present?
            @activities = @activities_data[:activity_list].reverse
          end
        end
      end

      def clear_saved_draft
        remove_tickets_redis_key(HELPDESK_REPLY_DRAFTS % { 
                                    :account_id => current_account.id, 
                                    :user_id => current_user.id, 
                                    :ticket_id => @item.notable_id
                                })
      end

      def flash_message(status)
        if @item.broadcast_note? && status == 'success'
          flash[:notice] = t(:"flash.tickets.notes.broadcast.#{status}", :count => @item.notable.related_tickets_count)
        else
          flash[:notice] = I18n.t(:"flash.general.create.#{status}", :human_name => cname.humanize.downcase)
        end
      end

      def note_to_kbase
        begin
          create_article if @create_solution_privilege
        rescue Exception => e
          NewRelic::Agent.notice_error(e)
        end
      end

      def has_unseen_notes?
        return false if params["last_note_id"].nil?
        last_public_note    = @parent.notes.conversations(nil, 'created_at DESC', 1).first
        late_public_note_id = last_public_note.blank? ? -1 : last_public_note.id
        return late_public_note_id > params["last_note_id"].to_i
      end

      def traffic_cop_warning
        return unless has_unseen_notes?
        @notes = @parent.conversation_since(params[:since_id]).reverse
        @public_notes = @notes.select{ |note| note.private == false || note.incoming == true }
        respond_to do |format|
          format.js {
            render :file => "helpdesk/notes/traffic_cop.rjs" and return true
          }
          format.nmobile {
            note_arr = []
            @public_notes.each do |note|
              note_arr << note.to_mob_json
            end
            render :json => { :traffic_cop_warning => true, :notes => note_arr }
          }
        end
      end

      def check_for_public_notes
        traffic_cop_warning unless params[:helpdesk_note][:private].to_s.to_bool
      end

      def check_trial_customers_limit
        if ((current_account.id > get_spam_account_id_threshold) && (!ismember?(SPAM_WHITELISTED_ACCOUNTS, current_account.id)))
          if (current_account.subscription.trial?) && max_to_cc_threshold_crossed?
            max_email_threshhold_check
            respond_to do |format|
              format.js { render :file => "helpdesk/notes/inline_error.rjs", :locals => { :msg => t(:'flash.general.recipient_limit_exceeded', :limit => get_trial_account_max_to_cc_threshold )} }
              format.html { redirect_to @parent }
              format.nmobile { render :json => { :server_response => false } }
              format.any(:json, :xml) { render request.format.to_sym => @item.errors, :status => 400 }
            end
          elsif(account_created_recently? && max_to_cc_threshold_crossed?)
            max_email_threshhold_check
          end
        end
      end

      def max_email_threshhold_check 
        ticket_ids = email_threshold_crossed_tickets(current_account.id, @parent.id)
        Rails.logger.info "Maximum email threshold crossed #{ticket_ids.count} time for Account :#{current_account.id}. Ticket ids #{ticket_ids.join(",")}" 
        if ticket_ids.count == 3
          subject = "Alert!! Maximum email threshold crossed third time for Account :#{current_account.id} "
          additional_info = "Ticket ids #{ticket_ids.join(",")}"
          notify_account_blocks(current_account, subject, additional_info)
        elsif ticket_ids.count == 5
          add_member_to_redis_set(SPAM_EMAIL_ACCOUNTS, current_account.id)
          current_account.launch(:spam_blacklist_feature)
          subject = "Reached Maximum email threshold limit for a day for Account :#{current_account.id} "
          additional_info = "Blocking outgoing emails and marked #{current_account.id} as spam. Ticket ids #{ticket_ids.join(",")}"
          notify_account_blocks(current_account, subject, additional_info)
          update_freshops_activity(current_account, "Outgoing emails blocked", "block_outgoing_email")
        end 
      end 

      def max_to_cc_threshold_crossed?
        note_cc_email = get_email_array(@item.cc_emails_hash[:cc_emails])
        note_to_email = get_email_array(@item.to_emails)
        note_bcc_email = get_email_array(@item.bcc_emails)
        ticket_from_email = get_email_array(@parent.from_email)
        cc_email_hash = @parent.cc_email_hash.nil? ? Helpdesk::Ticket.default_cc_hash : @parent.cc_email_hash

        bcc_emails = get_email_array(cc_email_hash[:bcc_emails])
        cc_emails = get_email_array(cc_email_hash[:cc_emails])
        fwd_emails = get_email_array(cc_email_hash[:fwd_emails])

        old_recipients = bcc_emails.present? ? (cc_emails | fwd_emails | ticket_from_email | bcc_emails) : (cc_emails | fwd_emails | ticket_from_email)
        total_recipients = old_recipients | note_cc_email | note_to_email | note_bcc_email
        Rails.logger.info "Total email for ticket #{@parent.id} are #{total_recipients.join(",")}" 
        return (total_recipients.count != old_recipients.count ) && (total_recipients.count) > get_trial_account_max_to_cc_threshold
      end

      def run_on_slave(&block)
        Sharding.run_on_slave(&block)
      end 

      def learn_valid_ticket_data
        if (current_account.proactive_spam_detection_enabled? && @parent.notes.count.zero? &&
         @parent.source.eql?(current_account.helpdesk_sources.ticket_source_keys_by_token[:email]) && !@parent.spam?)
          SpamDetection::LearnTicketWorker.perform_async({ :ticket_id => @parent.id, 
            :type => Helpdesk::Email::Constants::MESSAGE_TYPE_BY_NAME[:ham]})
          Rails.logger.info "Enqueued job to sidekiq to learn ticket"
        end
      end
end
