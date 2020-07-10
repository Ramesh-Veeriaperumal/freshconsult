class Helpdesk::TicketsController < ApplicationController

  require 'freemail'

  include HelpdeskControllerMethods
  include ActionView::Helpers::TextHelper
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Helpdesk::TicketActions
  include Search::TicketSearch
  include Helpdesk::Ticketfields::TicketStatus
  include Helpdesk::AdjacentTickets
  include Helpdesk::ToggleEmailNotification
  include ApplicationHelper
  include Mobile::Controllers::Ticket
  include CustomerDeprecationMethods::NormalizeParams
  helper AutocompleteHelper
  helper Helpdesk::NotesHelper
  helper Helpdesk::TicketsExportHelper
  helper Helpdesk::SelectAllHelper
  helper Helpdesk::RequesterWidgetHelper
  include Helpdesk::TagMethods
  include Helpdesk::NotePropertiesMethods
  include ParentChildHelper
  include Helpdesk::Activities
  include Helpdesk::Activities::ActivityMethods
  include Helpdesk::SpamAccountConstants
  include ParentChildHelper
  include TicketValidationMethods
  include ParserUtil
  include Redis::TicketsRedis
  include Helpdesk::SendAndSetHelper
  include CompaniesHelperMethods

  ALLOWED_QUERY_PARAMS = ['collab', 'message', 'follow']
  SCENARIO_AUTOMATION_ACTIONS = [:execute_scenario, :execute_bulk_scenario]

  before_filter(only: SCENARIO_AUTOMATION_ACTIONS) { |c| c.requires_bitmap_feature :scenario_automation }
  before_filter :redirect_to_mobile_url
  skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:show,:suggest_tickets]
  before_filter :portal_check, :verify_format_and_tkt_id, :only => :show
  before_filter :set_ui_preference, :only => [:index, :show]
  before_filter :check_compose_feature, :check_trial_outbound_limit, :only => :compose_email

  before_filter :find_topic, :redirect_merged_topics, :only => :new
  around_filter :run_on_slave, :only => [:user_ticket, :activities, :suggest_tickets, :bulk_fetch_ticket_fields]
  before_filter :save_article_filter, :only => :index
  around_filter :run_on_db, :only => [:custom_search, :index, :full_paginate]

  before_filter :set_mobile, :only => [ :index, :show,:update, :create, :execute_scenario, :assign, :spam , :update_ticket_properties , :unspam , :destroy , :pick_tickets , :close_multiple , :restore , :close ,:execute_bulk_scenario]
  before_filter :normalize_params, :only => :index
  before_filter :cache_filter_params, :only => [:custom_search]
  before_filter :load_cached_ticket_filters, :load_ticket_filter, :check_autorefresh_feature, :load_sort_order , :only => [:index, :filter_options, :old_tickets,:recent_tickets]
  before_filter :get_tag_name, :clear_filter, :only => [:index, :filter_options]
  before_filter :add_requester_filter , :only => [:index, :user_tickets]
  before_filter :load_filter_params, :only => [:custom_search], :if => :es_tickets_enabled?
  before_filter :load_article_filter, :only => [:index, :custom_search, :full_paginate]
  before_filter :disable_notification, :if => :notification_not_required?
  after_filter  :enable_notification, :if => :notification_not_required?
  before_filter :set_selected_tab

  layout :choose_layout

  before_filter :filter_params_ids, :only =>[:destroy,:assign,:close_multiple,:spam,:pick_tickets, :delete_forever, :delete_forever_spam, :execute_bulk_scenario, :unspam, :restore]
  before_filter :validate_bulk_scenario, :only => [:execute_bulk_scenario], :if => :close_validation_enabled?
  before_filter :validate_ticket_close, :only => [:close_multiple], :if => :close_validation_enabled?

  #Set Native mobile is above scoper ticket actions, because, we send mobile response in scoper ticket actions, and
  #the nmobile format has to be set. Else we will get a missing template error.
  before_filter :set_native_mobile, :only => [:show, :load_reply_to_all_emails, :index,:recent_tickets,:old_tickets , :delete_forever,:change_due_by,:reply_to_forward, :save_draft, :clear_draft, :assign]

  before_filter :load_items, :only => [ :destroy, :restore, :spam, :unspam, :assign,
    :close_multiple ,:pick_tickets, :delete_forever, :delete_forever_spam ], :if => :items_empty?

  before_filter :scoper_ticket_actions, :only => [:close_multiple, :pick_tickets, :assign, :destroy, :restore, :spam, :unspam], :if => :eligible_for_bulk?

  skip_before_filter :load_item
  alias :load_ticket :load_item

  before_filter :verify_ticket_permission_by_id, :only => [:component]

  before_filter :load_ticket,
    :only => [:edit, :update, :execute_scenario, :close, :change_due_by, :print, :clear_draft, :save_draft,
              :draft_key, :get_ticket_agents, :quick_assign, :prevnext, :status, :update_ticket_properties,
              :activities, :activitiesv2, :activities_all, :unlink, :associated_tickets, :ticket_association,
              :suggest_tickets, :update_requester, :refresh_requester_widget,:fetch_errored_email_details, :suppression_list_alert]

  before_filter :load_ticket_with_notes, :only => :show
  before_filter :load_ticket_contact_data, :only => [:show, :update_requester, :refresh_requester_widget]

  before_filter :check_outbound_permission, :only => [:edit, :update]

  skip_before_filter :build_item, :only => [:create, :compose_email]
  alias :build_ticket :build_item
  before_filter :build_ticket_body_attributes, :only => [:create]
  before_filter :build_ticket, :only => [:create, :compose_email]
  before_filter :set_required_fields, :check_trial_customers_limit, :only => :create

  before_filter :set_date_filter ,    :only => [:export_csv]
  before_filter :csv_date_range_in_days , :only => [:export_csv]
  before_filter :export_limit_reached? , :only => [:export_csv]
  before_filter :check_ticket_status, :only => [:update, :update_ticket_properties]
  before_filter :handle_send_and_set, :only => [:update_ticket_properties]
  before_filter :validate_manual_dueby, :only => :update
  before_filter :set_default_filter , :only => [:custom_search, :export_csv]

  before_filter :verify_permission, :only => [:show, :edit, :update, :execute_scenario, :close, :change_due_by, :print, :clear_draft, :save_draft,
              :draft_key, :get_ticket_agents, :quick_assign, :prevnext, :status, :update_ticket_properties, :activities, :unspam, :restore, :activitiesv2, :activities_all, :fetch_errored_email_details, :suppression_list_alert]

  before_filter :validate_scenario, :only => [:execute_scenario], :if => :close_validation_enabled?
  before_filter :validate_quick_assign_close, :only => [:quick_assign], :if => :close_validation_enabled?

  before_filter :load_email_params, :only => [:show, :reply_to_conv, :forward_conv, :reply_to_forward]
  before_filter :load_conversation_params, :only => [:reply_to_conv, :forward_conv, :reply_to_forward]
  before_filter :load_reply_to_all_emails, :only => [:show, :reply_to_conv],
    :unless => lambda { |controller|
      controller.request.format.xml? or controller.request.format.json? or controller.request.format.mobile? }
  before_filter :load_note_reply_cc, :only => [:reply_to_forward]
  before_filter :load_note_reply_from_email, :only => [:reply_to_forward]
  before_filter :show_password_expiry_warning, :only => [:index, :show]
  before_filter :load_assoc_parent, :only => [:new, :bulk_child_tkt_create]
  before_filter :load_tracker_ticket, :only => [:link, :unlink]

  after_filter  :set_adjacent_list, :only => [:index, :custom_search]
  before_filter :fetch_item_attachments, :only => [:create, :update]
  before_filter :load_tkt_and_templates, :only => :apply_template
  before_filter :check_ml_feature, :only => [:suggest_tickets]
  before_filter :load_parent_template, :only => [:show_children, :bulk_child_tkt_create]
  before_filter :load_associated_tickets, :only => [:associated_tickets]
  before_filter :outbound_email_allowed? , :only => [:create]
  before_filter :requester_widget_filter_params, :only => [:update_requester]
  before_filter :check_custom_view_feature, :only => [:custom_view_save]
  before_filter :remove_skill_param, :only => [:update_ticket_properties], unless: :has_edit_ticket_skill_privilege?

  # before_filter methods for send_and_set_status are to be added in send_and_set_helper.rb

  def check_custom_view_feature
    unless current_account.custom_ticket_views_enabled?
      redirect_to safe_send(Helpdesk::ACCESS_DENIED_ROUTE)
    end
  end

  def suggest_tickets
    tickets = []
    similar_tickets_list = get_similar_tickets
    tickets = current_account.tickets.visible.preload(:requester, :ticket_status, :ticket_body).permissible(current_user).reorder("field(helpdesk_tickets.id, #{similar_tickets_list.join(',')})").where(id: similar_tickets_list) if similar_tickets_list.present?
    tickets_list = []
    tickets.each do |ticket|
      similar_tickets = Hash.new
      similar_tickets["helpdesk_ticket"] = Hash.new
      ticket_id = ticket.id.to_s
      similar_tickets["helpdesk_ticket"]["display_id"] = ticket.display_id
      similar_tickets["helpdesk_ticket"]["subject"] = ticket.subject
      similar_tickets["helpdesk_ticket"]["description"] = ticket.description
      similar_tickets["helpdesk_ticket"]["updated_at"] = ticket.updated_at
      similar_tickets["helpdesk_ticket"]["requester_name"] = ticket.requester_name
      similar_tickets["helpdesk_ticket"]["status_name"] = ticket.status_name
      tickets_list << similar_tickets
    end
    render :json =>  tickets_list.compact.to_json
  end

  def bulk_fetch_ticket_fields
    # This method skips checking permissible(current_user) as we need to
    # return required fields for required ticket ids
    # irrespective of user permission over the ticket
    ticket_fields = []
    unless request.post?
      render :json => ticket_fields , :status => 405
    else
      tickets_list = params['ticket_list']
      fields_to_compute = (params['ticket_fields'] & TicketConstants::TFS_COMPUTE_FIELDS)
      # Below extra fields can not be obtained using select
      extra_fields_to_compute = (params['ticket_fields'] & TicketConstants::TFS_COMPUTE_FIELDS_EXTRA)
      if (fields_to_compute.present? or extra_fields_to_compute.present?) and tickets_list.present?
        tickets_list = tickets_list.first(TicketConstants::TFS_TICKETS_COUNT_LIMIT) # Limiting number of tickets
        fields_to_compute << "id"
        tickets = current_account.tickets.where(id:tickets_list).select(fields_to_compute)
        ticket_fields = tickets.each_with_object([]) {|ticket, return_list| return_list << get_properties_hash(ticket,fields_to_compute,extra_fields_to_compute)}
      end
      render :json => ticket_fields
    end
  end

  def get_properties_hash(ticket, fields_to_compute, extra_fields)
    fields_hash = fields_to_compute.map{|field| [field,ticket[field]]}.to_h
    extra_hash = extra_fields.select{|field| (ticket.respond_to? field)}.map{|field| [field, ticket.safe_send(field)]}.to_h
    fields_hash.merge(extra_hash).select{|_,field_value| (!field_value.nil?)}
  end

  def get_similar_tickets
    begin
      con = Faraday.new(MlAppConfig["host"]) do |faraday|
            faraday.response :json, :content_type => /\bjson$/                # log requests to STDOUT
            faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
          end
      response = con.post do |req|
        req.url "/"+MlAppConfig["url"]
        req.headers['Content-Type'] = 'application/json'
        req.headers['Authorization'] = MlAppConfig["auth_key"]
        req.options.timeout = MlAppConfig["timeout"]
        req.body = generate_body_suggest_tickets
      end
      Rails.logger.info "Response from ML : #{response.body["result"]}"
      response.body["result"]
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
      []
    end
  end

  def generate_body_suggest_tickets
    body =  {
            :account_id =>current_account.id.to_s,
            :ticket_id => @ticket.id.to_s,
            :product_id => @ticket.product_id.nil? ? TicketConstants::NBA_NULL_PRODUCT_ID: @ticket.product_id,
            :ticket_subject => @ticket.subject,
            :ticket_description => @ticket.description,
            :count =>MlAppConfig["ticket_count"].to_s,
            :source => @ticket.source.to_s
            }

    if current_user.group_ticket_permission
      body[:filter_condition] = {:group_id=>current_user.agent_groups.pluck(:group_id),:responder_id=> [current_user.id]}
    elsif current_user.assigned_ticket_permission
       body[:filter_condition] = {:responder_id => [current_user.id]}
    end
   Rails.logger.info "Resquest from ML : #{body}"
   body.to_json
  end

  def user_ticket
    if params[:email].present?
      @user = current_account.user_emails.user_for_email(params[:email])
    elsif params[:external_id].present?
      @user = current_account.users.find_by_external_id(params[:external_id])
    end
    if !@user.nil?
      @tickets =  current_account.tickets.visible.requester_active(@user).paginate(:page =>
                    params[:page],:per_page => 30)
    else
      @tickets = []
    end
    respond_to do |format|
      format.xml do
        render :xml => @tickets.to_xml
      end
      format.json do
        render :json => @tickets.to_json
      end
    end
  end

  def populate_sentiment
    if Account.current.customer_sentiment_ui_enabled?
      survey_association = Account.current.new_survey_enabled? ? "custom_survey_results" : "survey_results"
      sentiment_value = {}

      ticket_ids =  @items.map(&:id)

      sentiment_sql_array = ["select notable_id,int_nc04 from helpdesk_notes n inner join helpdesk_schema_less_notes sn
                    on n.id=sn.note_id and n.account_id=sn.account_id
                    where n.account_id = %s and n.notable_type = '%s' and n.notable_id in (%s) and sn.int_nc04 is not null
                    order by n.created_at;",
                    Account.current.id, 'Helpdesk::Ticket', ticket_ids.join(',')]

      sentiment_sql = ActiveRecord::Base.safe_send(:sanitize_sql_array, sentiment_sql_array)

      note_senti = ActiveRecord::Base.connection.execute(sentiment_sql).collect{|i| i}.to_h

      @items.each do |ticket|
        if ticket.safe_send(survey_association).nil? || ticket.safe_send(survey_association).last.nil?
          if note_senti[ticket.id].present?
            sentiment_value[ticket.id] = note_senti[ticket.id]
          else
            sentiment_value[ticket.id] = ticket.sentiment
          end
        end
      end
      sentiment_value
    end
  end

  def index
    #For removing the cookie that maintains the latest custom_search response to be shown while hitting back button
    params[:html_format] = request.format.html?
    tkt = current_account.tickets.permissible(current_user)
    @items = fetch_tickets unless is_native_mobile?
    @failed_tickets = []
    _tickets = []
    _ids_not_in_view = []
    (flash[:failed_tickets] || []).each do |_id|
      _ticket = @items.find {|_item| _item.display_id == _id}
      if _ticket.present?
        _tickets << _ticket
      else
        _ids_not_in_view << _id
      end
    end
    Rails.logger.debug "Ticket ids not in view #{_ids_not_in_view.inspect}"
    _tickets += current_account.tickets.where("display_id IN (?)", _ids_not_in_view) if _ids_not_in_view.present?
    _tickets.each do |_ticket|
      @failed_tickets << {:id => _ticket.id, :subject => CGI.escape_html(_ticket.subject.to_s), :display_id => _ticket.display_id}
    end
    if flash[:action]
      title = I18n.t("helpdesk.flash.title_on_#{flash[:action]}_fail")
      description = I18n.t("helpdesk.flash.description_on_#{flash[:action]}_fail")
    end
    @failed_tickets_data = {:failed_tickets => @failed_tickets, :title => title, :description => description } if @failed_tickets.present?
    respond_to do |format|
      format.html  do
        #moving this condition inside to redirect to first page in case of close/resolve of only ticket in current page.
        #For api calls(json/xml), the redirection is ignored, to use as indication of last page.
        if (@items.length < 1) && !params[:page].nil? && params[:page] != '1'
          params[:page] = '1'
          @items = fetch_tickets
        end
        @filters_options = scoper_user_filters.map { |i| {:id => i[:id], :name => i[:name], :default => false, :user_id => i.accessible.user_id} }
        @current_options = @ticket_filter.query_hash.map{|i|{ i["condition"] => i["value"] }}.inject({}){|h, e|h.merge! e}
        if !request.headers['X-PJAX'] || params[:pjax_redirect]
          # Bad code need to rethink. Pratheep
          @show_options = show_options
        end
        @current_view = @ticket_filter.id || @ticket_filter.name if is_custom_filter_ticket?
        flash[:notice] = t(:'flash.tickets.empty_trash.delay_delete') if @current_view == "deleted" and key_exists?(empty_trash_key)
        flash[:notice] = t(:'flash.tickets.empty_spam.delay_delete') if @current_view == "spam" and key_exists?(empty_spam_key)
        @is_default_filter = (!is_num?(view_context.current_filter))

        #Changes for customer sentiment - Beta feature
        #@sentiments = {:ticket_id => sentiment_value}
        if Account.current.customer_sentiment_ui_enabled? && @items.size > 0
          @sentiments = populate_sentiment
        end
        #End of changes for customer sentiment - Beta feature

        # if request.headers['X-PJAX']
        #   render :layout => "maincontent"
        # end
      end

      format.xml do
        render :xml => @response_errors.nil? ? @items.to_xml({:shallow => true}) : @response_errors.to_xml(:root => 'errors')
      end

      format.json do
        unless @response_errors.nil?
          render :json => {:errors => @response_errors}.to_json
        else
          array = []
          @items.preload(:ticket_body, :schema_less_ticket, flexifield: :flexifield_def).each do |tic|
            array << tic.as_json({}, false)['helpdesk_ticket']
          end
          render :json => array
        end
      end
	    format.mobile do
        unless @response_errors.nil?
          render :json => {:errors => @response_errors}.to_json
        else
          array = []
          @items.each { |tic|
            array << tic.as_json({
              :root => false,
              :except => [ :description_html, :description ],
              :methods => [ :status_name, :priority_name, :source_name, :requester_name,
                            :responder_name, :need_attention, :pretty_updated_date ]
            }, false)['helpdesk_ticket']
          }
          render :json => array
        end
      end
      format.nmobile do
        if(params[:fetch_mode].to_s.eql?("recent"))
          updated_time = DateTime.strptime(params[:latest_updated_at],'%s')
          tkt = tkt.latest_tickets(updated_time)
        end
        @items = tkt.filter(:params => params, :filter => 'Helpdesk::Filters::CustomTicketFilter')
        unless @response_errors.nil?
          render :json => {:errors => @response_errors}.to_json
        else
           tickets, hash = Array.new, {}
           @items.each do |tic|
            tickets <<  tic.to_mob_json_index['helpdesk_ticket']
           end
           hash.merge!({:ticket => tickets })
           hash.merge!(current_account.as_json(:only=>[:id],:methods=>[:portal_name]))
           hash.merge!(current_user.as_json({:only=>[:id], :methods=>[:display_name, :can_delete_ticket, :can_view_contacts, :can_delete_contact, :can_edit_ticket_properties, :can_view_solutions, :can_merge_or_split_tickets]}, true))
           hash.merge!({:summary => get_summary_count})
           hash.merge!({:top_view => top_view})
           render :json => hash
        end
      end
    end
  end

  def filter_options
    @current_options = @ticket_filter.query_hash.map{|i|{ i["condition"] => i["value"] }}.inject({}){|h, e|h.merge! e}
    @filters_options = scoper_user_filters.map { |i| {:id => i[:id], :name => i[:name], :default => false, :user_id => i.accessible.user_id} }
    @show_options = show_options
    @is_default_filter = (!is_num?(view_context.current_filter))
    @current_view = @ticket_filter.id || @ticket_filter.name if is_custom_filter_ticket?
    render :partial => "helpdesk/shared/filter_options", :locals => { :current_filter => @ticket_filter , :shared_ownership_enabled => current_account.shared_ownership_enabled?}
  end

  def filter_conditions
    filter_str = get_cached_filters
    if filter_str
      query_hash = JSON.parse(filter_str["data_hash"])
      is_default_filter = false
    else
      filter_name = params[:filter_key] || params[:filter_name]
      return render :json => {:error => "Invalid filter name" } if filter_name.blank?
      is_default_filter = !is_num?(filter_name) || invalid_custom_filter?(filter_name)
      if is_default_filter
        @ticket_filter = current_account.ticket_filters.new(Helpdesk::Filters::CustomTicketFilter::MODEL_NAME)
        query_hash = @ticket_filter.default_filter(filter_name)
      else
        query_hash = @ticket_filter.data[:data_hash]
      end
    end

    set_modes(query_hash)
    response_hash = current_account.shared_ownership_enabled? ? {:agent_mode => @agent_mode, :group_mode => @group_mode} : {}

    conditions_hash = query_hash.map{|i|{ i["condition"] => i["value"] }}.inject({}){|h, e|h.merge! e}
    meta_data       = filters_meta_data(conditions_hash) if conditions_hash.keys.any? {|k| META_DATA_KEYS.include?(k.to_s)}
    response_hash.merge!(
        { :conditions => conditions_hash,
          :default => is_default_filter,
          :meta_data => meta_data
        })

    render :json => response_hash
  end

  def invalid_custom_filter?(filter_name)
    @ticket_filter = current_account.ticket_filters.find_by_id(filter_name)
    @ticket_filter.nil? || !@ticket_filter.has_permission?(current_user)
  end

  def latest_ticket_count # Possible dead code
    index_filter =  current_account.ticket_filters.new(Helpdesk::Filters::CustomTicketFilter::MODEL_NAME).deserialize_from_params(params)
    ticket_count =  current_account.tickets.permissible(current_user).latest_tickets(params[:latest_updated_at]).where(index_filter.sql_conditions).count(:id)

    respond_to do |format|
      format.html do
        render :text => ticket_count
      end
    end
  end

  def user_tickets
    @items = current_account.tickets.permissible(current_user).filter(:params => params, :filter => 'Helpdesk::Filters::CustomTicketFilter')

    respond_to do |format|
      format.json do
        render :json => @items.to_json
      end

      format.widget do
        render :layout => "widgets/contacts"
      end
    end

  end

  def view_ticket
    if params['format'] == 'widget'
      @ticket = load_by_param(params[:id], preload_options)
      @item = @ticket
      if @ticket.nil?
        @item = @ticket = Helpdesk::Ticket.new
        @ticket.build_ticket_body
        render :new, :layout => "widgets/contacts"
      else
        if verify_permission
          @ticket_notes = run_on_slave { @ticket.conversation }
          @ticket_notes = @ticket_notes.take(3) if @ticket_notes.size > 3
          @ticket_notes = @ticket_notes.reverse
          @ticket_notes_total = run_on_slave { @ticket.conversation_count }
          render :layout => "widgets/contacts"
        else
          @no_auth = true
          render :layout => "widgets/contacts"
        end
      end
    end
  end

  def custom_view_save
    filter = current_account.user_accesses(current_user.id).find_by_accessible_id(view_context.current_filter)
    # Edit
    if params[:operation] and (params[:operation] == "edit") and !filter.nil?
      filter = filter.accessible
      render :partial => "helpdesk/tickets/customview/new",
             :locals => { :filter_name => filter.name, :visible_to => filter.accessible }
    # New
    else
      render :partial => "helpdesk/tickets/customview/new"
    end
  end

  def custom_search
    params[:html_format] = true
    @items = fetch_tickets

    #Changes for customer sentiment - Beta feature
    if Account.current.customer_sentiment_ui_enabled? && @items.size > 0
      @sentiments = populate_sentiment
    end
    #End of changes for customer sentiment - Beta feature

    @current_view = view_context.current_filter
    render :partial => "custom_search"
  end

  # Generating custom data hash
  # Since this is the only filter when data_hash will update for every pagination request
  def fetch_collab_tickets
    convo_id_arr = Collaboration::Ticket.new.fetch_tickets
    params["data_hash"] = Helpdesk::Filters::CustomTicketFilter.collab_filter_condition(convo_id_arr).to_json
    # Not using permissible(current_user) scope for group_collab collab-sub-feature
    if current_account.group_collab_enabled?
      current_account.tickets.preload({requester: [:avatar]}, :company).filter(:params => params, :filter => 'Helpdesk::Filters::CustomTicketFilter')
    else
      current_account.tickets.preload({requester: [:avatar]}, :company).permissible(current_user).filter(:params => params, :filter => 'Helpdesk::Filters::CustomTicketFilter')
    end
  end

  def show
    @to_emails = @ticket.to_emails

    draft_hash = get_tickets_redis_hash_key(draft_key)
    @draft = draft_hash ? draft_hash["draft_data"] : ""

    @subscription = current_user && @item.subscriptions.where(user_id: current_user.id).first if current_account.add_watcher_enabled?

    @page_title = "[##{@ticket.display_id}] #{@ticket.subject}"

    build_notes_last_modified_user_hash(@ticket_notes)

    # Only store recent tickets in redis which are not spam or not deleted
    Search::RecentTickets.new(@ticket.display_id).store unless @ticket.spam || @ticket.deleted

    respond_to do |format|
      format.html  {
        @ticket_notes       = @ticket_notes.reverse
        @ticket_notes_total = run_on_slave { @ticket.conversation_count }
        last_public_note    = run_on_slave { @ticket.notes.visible.last_traffic_cop_note.first }
        @last_note_id       = last_public_note.blank? ? -1 : last_public_note.id
        @last_broadcast_message = run_on_slave { @ticket.last_broadcast_message } if @ticket.related_ticket?
      }
      format.atom
      format.xml  {
        render :xml => @item.to_xml
      }
	    format.json {
		    render :json => @item.to_json
	    }
      format.js
      format.nmobile {
        hash = {}
        hash.merge!(@item.to_mob_json(false,false))
        hash.merge!(current_user.as_json({:only=>[:id], :methods=>[:can_reply_ticket, :can_edit_ticket_properties, :can_delete_ticket, :manage_scenarios,
                                                        :can_view_time_entries, :can_edit_time_entries, :can_forward_ticket, :can_edit_conversation, :can_manage_tickets]}, true))
        hash.merge!(current_account.as_json(:only=> [:id], :methods=>[:timesheets_feature]))
        hash.merge!({:subscription => !@subscription.nil?})
        hash.merge!({:reply_emails => @reply_emails})
        hash.merge!({:selected_email => @selected_reply_email})
        hash.merge!({:to_cc_emails => @to_cc_emails})
        hash.merge!({:bcc_drop_box_email => bcc_drop_box_email.map{|item|[item, item]}})
        hash.merge!({:last_reply => bind_last_reply(@ticket, @signature, false, true, true, true)})
        hash.merge!({:last_forward => bind_last_conv(@ticket, @signature, true)})
        hash.merge!({:ticket_properties => ticket_props})
        hash.merge!({:reply_template => parsed_reply_template(@ticket,nil)})
        hash.merge!({:default_twitter_body_val => default_twitter_body_val(@ticket)}) if @item.twitter?
        hash.merge!({:twitter_handles_map => twitter_handles_map}) if @item.twitter?
        hash.merge!({:tags => @item.tags.map(&:to_mob_json)})
        hash.merge!(@ticket_notes[0].to_mob_json) unless @ticket_notes[0].nil?
        hash.merge!({:ticket_draft => draft_hash})
        render :json => hash
      }
      format.mobile {
		 render :json => @item.to_mob_json
	  }
    end
  end

  def prevnext
    if collab_filter_with_group_collab_for?(view_context.current_filter)
      @previous_ticket = find_in_list(:prev)
      @next_ticket = find_in_list(:next)
    else
      @previous_ticket = find_adjacent(:prev)
      @next_ticket = find_adjacent(:next)
    end
  end

  def update
    #old_timer_count = @item.time_sheets.timer_active.size -  we will enable this later
    params[nscname] ||= {} #params[nscname] might be uninitialised in some cases when update happens via API
    build_attachments @item, :helpdesk_ticket
    params[nscname][:tag_names] = params[:helpdesk][:tags] unless params[:helpdesk].blank? or params[:helpdesk][:tags].nil?
    if @item.update_ticket_attributes(params[nscname])
      respond_to do |format|
        format.html {
          flash[:notice] = t(:'flash.general.update.success', :human_name => cname.humanize.downcase)
          redirect_to item_url
        }
        format.mobile {
          render :json => { :success => true, :item => @item }.to_json
        }
        format.xml {
          render :xml => @item.to_xml({:basic => true})
        }
        format.json {
          render :json => request.xhr? ? { :success => true }.to_json  : @item.to_json({:basic => true})
        }
      end
    else
      respond_to do |format|
        format.html { edit_error }
        format.json {
          result = {:errors=>@item.errors.full_messages }
          render :json => result.to_json
        }
        format.mobile {
          render :json => { :failure => true, :errors => edit_error }.to_json
        }
        format.xml {
          render :xml =>@item.errors
        }
      end
    end
  end

  def compose_email
    build_tkt_body
  end

  def update_ticket_properties
    params[nscname] ||= {} #params[nscname] might be uninitialised in some cases when update happens via API
    params[nscname][:tag_names] = params[:helpdesk][:tags] unless params[:helpdesk].blank? or params[:helpdesk][:tags].nil?
    can_close_assoc_parent?(@item, true) if [RESOLVED,CLOSED].include? params[:helpdesk_ticket][:status].to_i # check for parent tkt status
    if @item.update_ticket_attributes(params[nscname])
      if(params[:redirect] && params[:redirect].to_bool)
        flash[:notice] = render_to_string(:partial => '/helpdesk/tickets/close_notice', :formats => [:html], :handlers => [:erb] ).html_safe
      end
      verify_update_properties_permission
      respond_to do |format|
        format.html {
          flash[:notice] = t(:'flash.general.update.success', :human_name => cname.humanize.downcase)
          redirect_to item_url
        }
        format.mobile {
          render :json => { :success => true , :success_message => t(:'flash.general.update.success', :human_name => cname.humanize.downcase), :item => @item }.to_json
        }
        format.xml {
          render :xml => @item.to_xml({:basic => true})
        }
        format.json {
            response_params = { :success => true, :redirect => (params[:redirect] && params[:redirect].to_bool) }
            response_params.merge!(:autoplay_link => autoplay_link) if @item.trigger_autoplay?
            response_params.merge!(:err_msg => @status_err_msg) unless @status_err_msg.nil?
            render :json => request.xhr? ? response_params.to_json  : @item.to_json({:basic => true})
        }
      end
    else
      respond_to do |format|
        format.html { edit_error }
        format.mobile {
          render :json => { :failure => true, :errors => edit_error }.to_json
        }
        format.json {
          result = { err_msg: @item.errors.full_messages }
          render :json => result.to_json
        }
        format.json {
          render :json => { :failure => true, :errors => edit_error }.to_json
        }
        format.xml {
          render :xml =>@item.errors
        }
        format.mobile {
          render :json => { :failure => true, :errors => edit_error }.to_json
        }
      end
    end
  end

  def send_and_set_status
    can_close_assoc_parent?(@item, true) if [RESOLVED,CLOSED].include? params[:helpdesk_ticket][:status].to_i # check for parent tkt status
    @item.schedule_observer = true
    params[nscname][:tag_names] = params[:helpdesk][:tags] unless params[:helpdesk].blank? or params[:helpdesk][:tags].blank?
    verify_update_properties_permission if @item.assign_ticket_attributes(params[nscname])
    build_attachments @note, :helpdesk_note
    if @note.save_note
      enqueue_send_set_observer
      if is_reply?
        @note.send_survey = params[:send_survey]
        @note.include_surveymonkey_link = params[:include_surveymonkey_link]
        clear_saved_draft
        @ticket.add_forum_post(@note) if params[:post_forums]
        note_to_kbase
        flash[:notice] = t(:'flash.tickets.reply.success')
      end
      flash_message "success"
      process_and_redirect
    else
      note_type = is_reply? ? :reply : :note
      flash_message "failure"
      create_error(note_type)
    end

  end

  def refresh_requester_widget
    respond_to do |format|
      format.js { render :partial => "helpdesk/tickets/refresh_requester_widget" }
    end
  end

  def update_requester
    @requester = current_account.users.find_by_id(params[:requester_widget][:contact_id])
    return unless @requester.try(:customer?)

    company_save_success = true
    company_attributes = params[:company]
    company_name = company_attributes[:name] if company_attributes.present? && company_attributes[:name].present?
    if @company.blank? && company_name.present? && !@company_deleted
      @company = current_account.companies.find_by_name(company_name)
      @company ||= current_account.companies.new if current_user.privilege?(:manage_companies)
    end

    if @company && company_attributes && current_user.privilege?(:manage_companies)
        @company.assign_attributes(company_attributes)
        set_company_validatable_custom_fields
        set_validatable_default_fields
        company_save_success = @company.save
        check_domain_exists
        @filtered_contact_params[:customer_id] = @company.id if company_save_success && @requester.company.blank? && !@unassociated_company
        if !company_save_success && @existing_company.blank?
          flash[:notice] = activerecord_error_list(@company.errors)
        end
    end
    if company_save_success
      set_contact_validatable_custom_fields
      requester_success = @requester.update_attributes(@filtered_contact_params)
      ticket_success = (@ticket.company.blank? && @company.present? && requester_success ? @ticket.update_attributes(:owner_id => @company.id) : true)
      flash_message = if !requester_success
          activerecord_error_list(@requester.errors)
        elsif !ticket_success
          activerecord_error_list(@ticket.errors)
        else
          t(:'flash.general.update.success', :human_name => t('requester_widget_human_name'))
        end

      flash[:notice] = flash_message
    end
    @ticket.reload
    load_ticket_contact_data
  end

  def requester_widget_filter_params
    field_names = current_account.contact_form.default_contact_fields.map(&:name).delete_if{|n| n == "email"}
    field_names << :custom_field
    @filtered_contact_params = params[:contact].try(:slice, *field_names) || {}
  end

  def assign
    user = params[:responder_id] ? User.find(params[:responder_id]) : current_user
    assign_ticket user

    flash_message = t("helpdesk.flash.assignedto", :tickets => get_updated_ticket_count,
                                                :username => user.name )
    flash[:notice] = render_to_string(
      :inline => flash_message)


    respond_to do |format|
      format.html {
        if user === current_user && @items.size == 1
          redirect_to helpdesk_ticket_path(@items.first)
        else
          redirect_to :back
        end
      }
      format.xml { render :xml => @items.to_xml({:basic=>true}) }
      format.json { render :json => @items.to_json({:basic=>true}) }
      format.nmobile {render :json => {:message => flash_message}}
    end

  end

  def close_multiple
    @closed_tkt_count = 0
    status_id = CLOSED
    @items.each do |item|
      @closed_tkt_count += 1 if can_close_assoc_parent?(item) and item.update_attributes(:status => status_id)
    end
    respond_to do |format|
      format.html {
        flash[:notice] = (@failed_tickets.length == 0) ? render_to_string(:inline => t("helpdesk.flash.tickets_closed", :tickets => get_updated_ticket_count )) :
          render_to_string(
            :inline => t("helpdesk.flash.tickets_close_fail_on_bulk_close",
            :tickets => get_updated_ticket_count,
            :failed_tickets => "<%= link_to( t('helpdesk.flash.tickets_failed', :failed_count => @failed_tickets.count), '',  id: 'failed-tickets') %>" )).html_safe
        flash[:failed_tickets] = @failed_tickets
        flash[:action] = "bulk_close"
          redirect_to helpdesk_tickets_path
        }

        format.xml {  render :xml =>@items.to_xml({:basic=>true}) }

        format.mobile do
          response_hash = {}
          status = mobile_app_versioning? && ios? ? 400 : 200
          if @items.present?
            parents_not_closed = @items.length - @closed_tkt_count
            if @failed_tickets.present?
              error_code = parents_not_closed > 0 ? 1017 : 1016
              response_hash = {
                :success => false,
                :success_message => t("helpdesk.flash.tickets_close_fail_on_bulk_close_mobile",
                                          :tickets => get_updated_ticket_count, :failed_tickets => @failed_tickets.length ),
                :failed_on_required_fields => @failed_tickets.length,
                :failed_on_parent => parents_not_closed,
                :error => "Sorry your request could not be processed",
                :error_code => error_code,
                :closed_tickets => @closed_tkt_count
              }
            else
              error_code, success, status = parents_not_closed > 0 ? [1015, false, status] : [nil, true, 200]
              response_hash = {
                :success => success,
                :success_message => t("helpdesk.flash.tickets_closed",
                                          :tickets => get_updated_ticket_count ),
                :failed_on_required_fields => 0,
                :error => "Sorry your request could not be processed",
                :failed_on_parent => parents_not_closed,
                :error_code => error_code,
                :closed_tickets => @closed_tkt_count
              }
            end
          else
            response_hash = {
              :success => false,
              :error => "Sorry your request could not be processed",
              :failed_on_required_fields => @failed_tickets.length,
              :failed_on_parent => 0,
              :error_code => 1016,
              :closed_tickets => @closed_tkt_count
            }
          end
          render :json => response_hash.to_json, :status => status
        end

        format.json {  render :json =>@items.to_json({:basic=>true}) }
    end
  end

  def pick_tickets
    assign_ticket current_user
    flash[:notice] = render_to_string(
        :inline => t("helpdesk.flash.assigned_to_you", :tickets => get_updated_ticket_count ))
    respond_to do |format|
      format.html{ redirect_to :back }
      format.xml { render :xml => @items.to_xml({:basic=>true}) }
      format.mobile { render :json => { :success => true , :success_message => t("helpdesk.flash.assigned_to_you",
                                        :tickets => get_updated_ticket_count )}.to_json }
      format.json { render :json=>@items.to_json({:basic=>true}) }
    end
  end

  def execute_bulk_scenario
    @va_rule ||= current_account.scn_automations.find_by_id(params[:scenario_id])
    if @va_rule.present? and @va_rule.visible_to_me? and @va_rule.check_user_privilege
      ::Tickets::BulkScenario.perform_async({:ticket_ids => params[:ids], :scenario_id => params[:scenario_id]})
      @va_rule.fetch_actions_for_flash_notice(current_user)
      actions_executed = Va::RuleActivityLogger.activities
      Va::RuleActivityLogger.clear_activities
      respond_to do |format|
        format.html {
            flash[:failed_tickets] = @failed_tickets
            flash[:action] = "bulk_scenario_close"
            flash[:notice] = render_to_string(:partial => '/helpdesk/tickets/execute_scenario_notice',
                                          :locals => { :actions_executed => actions_executed, :rule_name => @va_rule.name, :bulk_scenario => true, :count => params[:ids].length, :failed_tickets => @failed_tickets}).html_safe
            redirect_to :back
          }
      end
    else
      scenario_failure_notification
    end
  end

  def execute_scenario
    @va_rule ||= current_account.scn_automations.find_by_id(params[:scenario_id])
    if @valid_ticket || (@va_rule.present? and @va_rule.visible_to_me? and @valid_ticket.nil?)
      if @va_rule.trigger_actions(@item, current_user)
        @item.save
        @item.create_scenario_activity(@va_rule.name)
        @va_rule_executed = @va_rule
        actions_executed = Va::RuleActivityLogger.activities
        Va::RuleActivityLogger.clear_activities
        respond_to do |format|
          format.html {
            flash[:notice] = render_to_string(:partial => '/helpdesk/tickets/execute_scenario_notice',
                                          :locals => { :actions_executed => actions_executed, :rule_name => @va_rule.name, :failed_tickets => [] }).html_safe
            redirect_to :back
          }
          format.xml { render :xml => @item }
          format.mobile {
            render :json => {:success => true, :id => @item.id, :actions_executed => actions_executed, :rule_name => @va_rule.name , :success_message => t("activities.tag.execute_scenario") }.to_json
          }
          format.json { render :json => @item }
          format.js {
            flash[:notice] = render_to_string(:partial => '/helpdesk/tickets/execute_scenario_notice',
                                          :locals => { :actions_executed => actions_executed, :rule_name => @va_rule.name, :failed_tickets => [] }).html_safe
          }
        end
      else
        scenario_failure_notification
      end
    else
      scenario_failure_notification
    end
  end

  def mark_requester_deleted(item,opt)
    req = item.requester
    req.deleted = opt
    req.save if req.customer?
  end

  def spam
    @req_list = []

    @items.each do |item|
      item.spam = true
      req = item.requester
      @req_list << req.id if req.customer?
      store_dirty_tags(item)
      item.save

      Search::RecentTickets.new(item.display_id).delete if item.is_a?(Helpdesk::Ticket)
    end

    display_spam_flash
  end

  def unspam
    @items.each do |item|
      item.spam = false
      restore_dirty_tags(item)
      item.save
      #mark_requester_deleted(item,false)
    end
    display_unspam_flash
  end

  def delete_forever
    set_trashed_column
    Tickets::ClearTickets::EmptyTrash.perform_async({
      :ticket_ids => @items.map(&:id)
    })
    render_delete_forever
  end

  def delete_forever_spam
    set_trashed_column
    Tickets::ClearTickets::EmptySpam.perform_async({
      :ticket_ids => @items.map(&:id)
    })
    render_delete_forever
  end

  def sentiment_feedback

    Rails.logger.info "In sentiment_feedback"

    if current_user.has_ticket_permission?(@item)

      fb_params = {}

      con = Faraday.new(MlAppConfig["sentiment_host"]) do |faraday|
          faraday.response :json, :content_type => /\bjson$/                # log requests to STDOUT
          faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
      end

      fb_params = {"data"=> {:account_id=>current_account.id,
                            :ticket_id=>params["data"]["ticket_id"],
                            :note_id=>params["data"]["note_id"],
                            :predicted_value=>params["data"]["predicted_value"],
                            :feedback=>params["data"]["feedback"],
                            :user_id=>current_user.id,
                            }}

      response = con.post do |req|
        req.url "/"+MlAppConfig["feedback_url"]
        req.headers['Authorization'] = MlAppConfig["auth_key"]
        req.headers['Content-Type'] = 'application/json'
        req.body = fb_params.to_json
      end
    end
    render :json => {"success"=>"true"}.to_json

  end

  def empty_trash
    set_tickets_redis_key(empty_trash_key, true, 1.day)
    Tickets::ClearTickets::EmptyTrash.perform_async({
      :clear_all => true
    })
    flash[:notice] = t(:'flash.tickets.empty_trash.delay_delete')
    redirect_to :back
  end

  def empty_spam
    set_tickets_redis_key(empty_spam_key, true, 1.day)
    Tickets::ClearTickets::EmptySpam.perform_async({
      :clear_all => true
    })
    flash[:notice] = t(:'flash.tickets.empty_spam.delay_delete')
    redirect_to :back
  end

  def link
    params[:ids].present? ? link_multiple : link_to_tracker

    flash[:notice] = @item.errors[:base][0] if @item && @item.errors.any?
    respond_to do |format|
      format.html { redirect_to :back }
      format.js
    end
  end

  def unlink
    @item.association_type = nil
    @item.tracker_ticket_id = params[:tracker_id]
    @item.save
    flash[:notice] = @item.errors.any? ? @item.errors[:base][0] : t(:'flash.tickets.unlink.success')
    respond_to do |format|
      format.html { redirect_to :back }
      format.js { render :file => 'helpdesk/tickets/link.rjs' }
    end
  end

  def ticket_association
    @associates = @ticket.associates unless @ticket.association_type.blank?
    @last_broadcast_message = run_on_slave { @ticket.last_broadcast_message } if @ticket.related_ticket?
    respond_to do |format|
      format.html { render :partial => "/helpdesk/tickets/show/ticket_association", :locals => { :ticket => @ticket } }
    end
  end

  def change_due_by
    due_date = get_due_by_time
    update_success = true
    unless @item.update_attributes({:due_by => due_date, :manual_dueby => true})
      update_success = false
      flash[:error] = @item.errors.messages[:base]
      @item.reload
    end
    respond_to do |format|
      format.any(:html,:js) {
        render :partial => "/helpdesk/tickets/show/due_by", :object => @item.due_by
      }
      format.nmobile {
          render :json => {:success => update_success, :msg => @item.errors.full_messages }
      }

    end
  end

  def get_due_by_time
    due_date_option = params[:due_date_options]
    due_by_time = params[:due_by_date_time]

    case due_date_option.to_sym()
    when :today
      Time.zone.now.end_of_day
    when :tomorrow
      Time.zone.now.tomorrow.end_of_day
    when :thisweek
      Time.zone.now.end_of_week
    when :nextweek
      Time.zone.now.next_week.end_of_week
    else
      Time.parse(due_by_time).to_s(:db)
    end
  end

  def get_ticket_agents
    unless @item.blank?
      @agents = current_account.agents
    end
    render :partial => "get_ticket_agents", :locals => {:ticket_id => @item.display_id}
  end


  def quick_assign
    if allowed_quick_assign_fields.include?(params[:assign])
      unless params[:assign] == 'agent'
        @item.safe_send( params[:assign] + '=' ,  params[:value]) if @item.respond_to?(params[:assign])
      else
        @item.responder = nil
        @item.responder = current_account.users.find(params[:value]) unless params[:value]== "-"
      end
      @item.save
      render :json => {:success => true}.to_json
    else
      render :json => {:success => false}.to_json
    end
  end

  def edit
    @item.build_ticket_body(:description_html => @item.description_html,
        :description => @item.description) unless @item.ticket_body
  end

  def new
    if !@topic.nil? #convert topic to tkt
      @item.subject   = @topic.title
      @item.description_html = @topic.posts.first.body_html
      @item.requester = @topic.user
    elsif params[:ticket_id].present? #create child tkt manually
      can_be_assoc_parent? ? assign_parent_to_new_child : redirect_to(helpdesk_ticket_path(params[:ticket_id]),
        :flash => { :notice => t('flash.general.access_denied') })
    else
      build_tkt_body
    end

    if params['format'] == 'widget'
      render :layout => 'widgets/contacts'
    end
  end

  def create
    if (!params[:topic_id].blank? && find_topic) && (@topic.ticket.nil? || (@topic.ticket.present? && @topic.ticket.deleted))
      @item.source = current_account.helpdesk_sources.ticket_source_keys_by_token[:forum]
      @item.build_ticket_topic(:topic_id => params[:topic_id])
    end

    @item.product ||= current_portal.product
    cc_emails = fetch_valid_emails(params[:cc_emails])

    #Using .dup as otherwise its stored in reference format(&id0001 & *id001).
    @item.cc_email = {:cc_emails => cc_emails, :fwd_emails => [], :bcc_emails => [], :reply_cc => cc_emails.dup, :tkt_cc => cc_emails.dup}

    @item.status = CLOSED if save_and_close?
    @item.display_id = params[:helpdesk_ticket][:display_id]
    @item.email = params[:helpdesk_ticket][:email]
    @item.group = current_account.groups.find_by_id(params[:helpdesk_ticket][:group_id]) if params[:helpdesk_ticket][:group_id]
    @item.tag_names = params[:helpdesk][:tags] unless params[:helpdesk].blank? or params[:helpdesk][:tags].nil?
    if current_account.link_tickets_enabled? and params[:display_ids].present?
      @item.association_type = TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:tracker]
      @item.related_ticket_ids = params[:display_ids].split(',')
    end
    build_attachments @item, :helpdesk_ticket
    persist_states_for_api
    set_ticket_association

    if @item.save_ticket
      child_tkt_post_persist
      set_redirect_path if @item.tracker_ticket?
      post_persist
      notify_cc_people cc_emails unless (cc_emails.blank? || @item.outbound_email?)
    else
      create_error
    end
  end

  ## API to import resolved and closed ticket details
  def persist_states_for_api
    if params[:format].eql?('json')
      @item.ticket_states = Helpdesk::TicketState.new

      # Overriding created_at in case of ticket import
      states_created_at  = convert_to_time(params[:helpdesk_ticket][:created_at])
      @item.ticket_states.created_at = states_created_at if !states_created_at.nil?

      if params.key?(:resolved_at) or params.key?(:closed_at)
        resolved_at = convert_to_time(params[:resolved_at])
        closed_at = convert_to_time(params[:closed_at])

        if @item.status == RESOLVED and !resolved_at.nil?
          @item.ticket_states.resolved_at = resolved_at
        elsif @item.status == CLOSED and !closed_at.nil?
          @item.ticket_states.resolved_at = @item.ticket_states.closed_at = closed_at
        end
      end

    end
  end

  def convert_to_time(time_string)
    time = nil

    # Store previous TZ:
    old_tz = Time.zone
    Time.zone = "UTC"

    begin
      # Parse time with default TZ set as UTC:
      time = time_string.nil? ? nil : Time.parse(time_string)
    rescue ArgumentError
      Rails.logger.error("Time format mismatch. Start time and end time should be like #{Time.now.to_formatted_s(:db)}")
    ensure
      # Reset to previous TZ:
      Time.zone = old_tz
    end
    time
  end

  def close
    status_id = CLOSED
    #@old_timer_count = @item.time_sheets.timer_active.size - will enable this later..not a good solution
    if can_close_assoc_parent? and @item.update_attributes(:status => status_id)
      respond_to do |format|
        format.html {
          flash[:notice] = render_to_string(:partial => '/helpdesk/tickets/close_notice')
          redirect_to redirect_url
        }
          format.mobile {  render :json => { :success => true , :success_message => t("helpdesk.tickets.close_notice.ticket_has_been_cloased") }.to_json }
       end
    else
      flash[:error] = t("helpdesk.flash.closing_the_ticket_failed")
      respond_to do |format|
        format.html { redirect_to :back  }
        format.mobile {  render :json => { :success => false }.to_json }
      end
    end
  end

  def get_solution_detail
    language = Language.find_by_code(params[:language]) || Language.for_current_account
    sol_desc = current_account.solution_article_meta.find(params[:id]).safe_send("#{language.to_key}_article")
    @sol_attach = sol_desc.attachments
    @sol_cloud_files = sol_desc.cloud_files
    @sol_description = Helpdesk::HTMLSanitizer.sanitize_for_insert_solution(sol_desc.description) || ""
    render :partial => '/helpdesk/tickets/components/insert_solutions.rjs'
  end

  def latest_note
    ticket = current_account.tickets.permissible(current_user).find_by_display_id(params[:id])
    respond_to do |format|

      format.html {
        if ticket.nil?
          render :text => t("flash.general.access_denied")
        else
          render :partial => "/helpdesk/shared/ticket_overlay", :locals => {:ticket => ticket}
        end
      }
      format.nmobile {
        if ticket.nil?
            access_denied
        else
          latest_note_hash = latest_note_helper(ticket)
          overlay_user = latest_note_hash[:user]
          user_hash = {
            :user => { :name => overlay_user.name, :avatar_url => overlay_user.medium_avatar}
          }
          user_hash[:group] =  {:name => latest_note_hash[:ticket_group].name, :id => latest_note_hash[:ticket_group].id} if latest_note_hash[:ticket_group]
          latest_note_hash.except!(:user, :ticket_group)
          latest_note_hash.merge!(user_hash)
          render :json => latest_note_hash.to_json()
        end
      }
    end
  end

  def save_draft
    count = 0
    tries = 3
    success = true
    begin
      params[:draft_data] = Helpdesk::HTMLSanitizer.clean(params[:draft_data])
      draft_cc = fetch_valid_emails(params[:draft_cc]).map {|e| "#{e};"}.to_s.sub(/;$/,"")
      draft_bcc = fetch_valid_emails(params[:draft_bcc]).map {|e| "#{e};"}.to_s.sub(/;$/,"")
      draft_inline_attachment_ids = params["inline_attachment_ids"].is_a?(Array) ? params["inline_attachment_ids"] : []
      draft_hash_data = {
        "draft_data" => params[:draft_data],
        "draft_cc" => draft_cc,
        "draft_bcc" => draft_bcc,
        "draft_inline_attachment_ids" => draft_inline_attachment_ids.join(",")
      }
      set_tickets_redis_hash_key(draft_key, draft_hash_data)
    rescue Exception => e
      success = false
      NewRelic::Agent.notice_error(e,{:key => draft_key,
        :value => params[:draft_data],
        :description => "Redis issue",
        :count => count})
      if count<tries
          count += 1
          retry
      end
    end

     respond_to do |format|
         format.html {
            render :nothing => true
         }
         format.nmobile{
            render :json => {:success => success}
         }
     end

  end

  def clear_draft
    remove_tickets_redis_key(draft_key)
     respond_to do |format|
         format.html {
            render :nothing => true
         }
         format.nmobile{
            render :json => {:success => true}
         }
     end
  end

  def activities
    return activity_json if request.format == "application/json"
    options = [:user => :avatar]
    if params[:since_id].present?
      activity_records = @item.activities.activity_since(params[:since_id]).includes(options)
    elsif params[:before_id].present?
      activity_records = @item.activities.activity_before(params[:before_id]).includes(options)
    else
      activity_records = @item.activities.newest_first.includes(options).first(3)
    end

    @activities = stacked_activities(@item, activity_records.reverse)
    @total_activities =  @item.activities_count
    if params[:since_id].present? or params[:before_id].present?
      render :partial => "helpdesk/tickets/show/activity.html.erb", :collection => @activities
    else
      render :layout => false
    end
  end

  def activitiesv2
    if request.format != "application/json" && ACTIVITIES_ENABLED
      type = :tkt_activity
      @activities_data = new_activities(params, @item, type)
      @total_activities  ||=  @activities_data[:total_count]
       respond_to do |format|
        format.html{
          if @activities_data.nil? || @activities_data[:error].present?
            render nothing: true
          else
            @activities = @activities_data[:activity_list].reverse
            if params[:since_id].present? or params[:before_id].present?
              render :partial => "helpdesk/tickets/show/custom_activity.html.erb", :collection => @activities
            else
              render :layout => false
            end
          end
        }
      end
    else
      render :nothing => true
    end
  end

  def activities_all
    if request.format != "application/json"
      activities = {:activity => "Incorrect request format"}
    else
      params[:event_type] = ::HelpdeskActivities::EventType::ALL
      params[:limit]      = 200
      activities = new_activities(params, @item, :test_json)
    end
    respond_to do |format|
      format.json do
        render :json => activities
      end
    end
  end

  def status
    render :partial => 'helpdesk/tickets/show/status.html.erb', :locals => {:ticket => @ticket}
  end

  def summary
    view_name = params[:view_name] || "new_and_my_open"
    count = {:error => "Unsupported view name"}
    if supported_view.include? view_name.to_sym
      count = {:view_count => filter_count(view_name.to_sym)}
    end
    respond_to do |format|
      format.json{
        render :json => count.to_json
      }
      format.xml {
        render :xml => count.to_xml(:root => :count)
      }
      format.any {
       render_404
      }
    end
  end

  def accessible_templates
    recent_ids = recent_templ_ids
    if recent_ids.present?
      recent_templ = fetch_templates(["`ticket_templates`.id IN (?) and
        `ticket_templates`.association_type IN (?)",recent_ids, set_assn_types], set_assn_types, recent_ids, RECENT_TEMPLATES)
    else
      recent_ids   = ""
      recent_templ = []
    end
    size = ITEMS_TO_DISPLAY - recent_templ.count
    acc_templ = fetch_templates(["`ticket_templates`.id NOT IN (?) and
      `ticket_templates`.association_type IN (?)",recent_ids, set_assn_types], set_assn_types, nil, size, recent_ids)
    render :json => { :all_acc_templates => acc_templ, :recent_templates => recent_templ }
  end

  def search_templates
    search_acc_templ = fetch_templates(["`ticket_templates`.name like ? and
      `ticket_templates`.association_type IN (?)","%#{params[:search_string]}%", set_assn_types], set_assn_types)
    render :json => { :all_acc_templates => search_acc_templ }
  end

  def apply_template
    @template  = current_account.prime_templates.find_by_id(params[:template_id])
    @template  = nil unless @template and @template.visible_to_me?

    if @template
      @all_attachments = @template.all_attachments
      @cloud_files = @template.cloud_files
      @template.template_data.each do |key,value|
        next if (compose_email? && invisible_fields?(key)) || !@item.respond_to?("#{key}=")
        key == "tags" ? (@item[key] = value) : (@item.safe_send("#{key}=",value))
      end
      @item.description_html = @template.data_description_html
    else
      flash[:notice] = t('ticket_templates.not_available')
    end
    respond_to do |format|
      format.js { render :partial => "/helpdesk/tickets/apply_template" }
    end
  end

  def show_children
    @parent_template  = nil unless @parent_template and @parent_template.visible_to_me?
    if @parent_template
      @cd_templates = @parent_template.child_templates
    else
      flash[:notice] = t('ticket_templates.not_available')
    end
    respond_to do |format|
      format.html {
        render :partial => 'helpdesk/tickets/show/select_childs_template', :locals => { :child_templates => @cd_templates, :parent_template => @parent_template }
      }
    end
  end

  def bulk_child_tkt_create
    if can_be_assoc_parent? and @parent_template and @parent_template.visible_to_me?
      if @assoc_parent_ticket.association_type.nil? || check_child_limit
        ::Tickets::BulkChildTktCreation.perform_async({
          :user_id               => current_user.id,
          :portal_id             => current_portal.id,
          :assoc_parent_tkt_id   => @assoc_parent_ticket.display_id,
          :parent_templ_id       => @parent_template.id,
          :child_ids             => params[:child_ids]
          })
        notice = I18n.t('ticket_templates.child_creation')
      else
        notice = I18n.t('ticket_templates.limit_exceeded', :limit => TicketConstants::CHILD_TICKETS_PER_ASSOC_PARENT)
      end
    else
      notice = t('ticket_templates.parent_not_accessible')
    end
    if params[:action].eql?("create")
      flash[:notice] = "#{I18n.t(:'flash.general.create.success',:human_name => I18n.t(:'ticket.parent_ticket'))} #{notice}"
    else
      render :json => { :success =>  true, :msg => notice }.to_json
    end
  end

  def associated_tickets
    if params[:page].present?
      render( :partial => "helpdesk/tickets/show/associated_ticket",
        collection: @associated_tickets)
    else
      render :partial => "helpdesk/tickets/show/associated_tickets_container"
    end
  end

  protected

    def autoplay_link
      next_ticket_id = run_on_slave {
        current_account.tickets.visible.next_autoplay_ticket(current_account,current_user.id).first.try(:display_id)
      }
      next_ticket_id ? helpdesk_ticket_path(next_ticket_id) : ""
    end

    def item_url
      return compose_email_helpdesk_tickets_path if params[:save_and_compose]
      return new_helpdesk_ticket_path if params[:save_and_create]
      return helpdesk_tickets_path if save_and_close?
      @item
    end

    def after_destroy_url
      redirect_url
    end

    def redirect_url
      helpdesk_tickets_path
    end

    def process_item
       @item.spam = false
       flash[:notice] = render_to_string(:partial => '/helpdesk/tickets/save_and_close_notice') if save_and_close?
    end

    def assign_ticket user
      @items.each do |item|
        item.responder = user
        #item.train(:ham) #Temporarily commented out by Shan
        item.save
      end
    end

    def choose_layout
      layout_name = request.headers['X-PJAX'] ? 'maincontent' : 'application'
      case action_name
        when "print"
          layout_name = 'print'
      end
      layout_name
    end

    def get_updated_ticket_count
      if @items.length == 1 and @items.first.tracker_ticket?
        t('tracker_was')
      else
        items_count = @closed_tkt_count ? @closed_tkt_count : @items.length
        pluralize(items_count, t('ticket_was'), t('tickets_were'))
      end
  end

   def is_num?(str)
    Integer(str.to_s)
   rescue ArgumentError
    false
   else
    true
  end

  def load_email_params
    @email_config = current_account.primary_email_config
    @reply_emails = current_account.features?(:personalized_email_replies) ? current_account.reply_personalize_emails(current_user.name) : current_account.reply_emails
    @ticket ||= current_account.tickets.find_by_display_id(params[:id])
    @ticket.escape_liquid_attributes = current_account.launched?(:escape_liquid_for_reply)
    @signature = current_user.agent.parsed_signature('ticket' => @ticket, 'helpdesk_name' => @ticket.account.helpdesk_name)
    @selected_reply_email = current_account.features?(:personalized_email_replies) ? @ticket.friendly_reply_email_personalize(current_user.name) : @ticket.selected_reply_email
  end

  def load_conversation_params
    @conv_id = params[:note_id]
    @note = @ticket.notes.visible.find_by_id(@conv_id) unless @conv_id.nil?
  end

  def load_reply_to_all_emails
    default_notes_count = "nmobile".eql?(params[:format])? 1 : 3
    @ticket_notes = @ticket.conversation(nil,default_notes_count)
    reply_to_all_emails
  end

  def load_note_reply_cc
    @to_cc_emails, @to_email = @note.load_note_reply_cc
  end

  def load_by_param(id, options = {}, archived = false)
    archived ? current_account.archive_tickets.find_by_param(id, current_account, options) : current_account.tickets.find_by_param(id, current_account, options)
  end

  def load_note_reply_from_email
    from_emails = @note.load_note_reply_from_email
    @selected_from_email_addr = nil
    from_emails.each do|from_email|
      @selected_from_email_addr = @reply_emails.find { |email_config| from_email == parse_email_text(email_config[1])[:email].downcase }
        break if @selected_from_email_addr
    end
    @from_emails = @reply_emails
  end

  private

    def handle_falcon_redirection
      options = {
        request_referer: request.referer,
        not_html: !request.format.html?,
        path_info: request.path_info,
        is_ajax: request.xhr?,
        env_path: env['PATH_INFO']
      }
      result = FalconRedirection.falcon_redirect(options)
      redirect_to (result[:path] + get_valid_query_string) if result[:redirect]
    end

    def get_valid_query_string
      query_params = Rack::Utils.parse_nested_query(request.query_string)
      query = query_params.slice(*ALLOWED_QUERY_PARAMS).to_query
      return "?#{query}" if query
      ""
    end

    def outbound_email_allowed?
      return unless params[:helpdesk_ticket].present?
      access_denied if (!current_account.verified? && params[:helpdesk_ticket][:source].to_i == current_account.helpdesk_sources.ticket_source_keys_by_token[:outbound_email])
    end

    def set_trashed_column
      sql_array = ["update helpdesk_schema_less_tickets st inner join helpdesk_tickets t on
                    st.ticket_id= t.id and st.account_id=%s and t.account_id=%s
                    set st.%s = 1 where t.id in (%s)",
                    current_account.id, current_account.id, Helpdesk::SchemaLessTicket.trashed_column, @items.map(&:id).join(',')]
      sql = ActiveRecord::Base.safe_send(:sanitize_sql_array, sql_array)

      ActiveRecord::Base.connection.execute(sql)
    end

    def render_delete_forever
      flash[:notice] = render_to_string(
          :inline => t("flash.tickets.delete_forever.success", :tickets => get_updated_ticket_count ))
      respond_to do |format|
        format.html { redirect_to :back }
        format.nmobile { render :json => {:success => true , :success_message => render_to_string(
          :inline => t("flash.tickets.delete_forever.success", :tickets => get_updated_ticket_count ))}}
      end
    end

    def params_for_bulk_action
      params.slice('ids','responder_id','disable_notification')
    end

    def scoper_ticket_actions
      ticket_actions_background
      req_list if action_name.to_sym == :spam
      if [:spam, :destroy, :unspam, :restore].include? action_name.to_sym
        safe_send("display_#{action_name}_flash")
      else
        flash_message = t('helpdesk.flash.tickets_background')
        respond_to do |format|
          format.html {
            if @failed_tickets.length == 0
              flash[:notice] = flash_message
            else
              flash[:failed_tickets] = @failed_tickets
              flash[:action] = "bulk_close"
              flash[:notice] = render_to_string(
              :inline => t("helpdesk.flash.tickets_close_fail_on_bulk_close",
              :tickets => get_updated_ticket_count,
              :failed_tickets => "<%= link_to( t('helpdesk.flash.tickets_failed', :failed_count => @failed_tickets.count), '',  id: 'failed-tickets') %>" )).html_safe
            end
            redirect_to helpdesk_tickets_path
          }
          format.nmobile {render :json => {:message => flash_message}}
        end
      end
    end

    def ticket_actions_background
      args = { :action => action_name }
      args.merge!(params_for_bulk_action)
      Rails.logger.debug "ids while queueing #{params[:ids].inspect}"
      ::Tickets::BulkTicketActions.perform_async(args) if params[:ids].present?
    end

    def find_topic
    	@topic = current_account.topics.where(id: params[:topic_id]).first unless params[:topic_id].nil?
    end

    def redirect_merged_topics
      return if params[:topic_id].nil? || @topic.blank? || !@topic.merged_topic_id?
      flash[:notice] = t("portal.tickets.merged_topic_note")
      redirect_to discussions_topic_path(params[:topic_id])
    end

    def supported_view
      [:all, :open, :overdue, :due_today, :on_hold, :new, :new_and_my_open, :my_groups_open]
    end

    def reply_to_all_emails
      if @ticket_notes.blank?
        @to_cc_emails = @ticket.reply_to_all_emails
      else
        @to_cc_emails = @ticket.current_cc_emails
      end
    end

    def redis_key
      HELPDESK_TICKET_FILTERS % {:account_id => current_account.id, :user_id => current_user.id, :session_id => request.session_options[:id]}
    end

    def allowed_quick_assign_fields
      ['agent', 'status', 'priority']
    end

    def cache_filter_params
      filter_params = params.clone
      filter_params.delete(:action)
      filter_params.delete(:controller)
      begin
        set_tickets_redis_key(redis_key, filter_params.to_json, 86400)
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
      end

      @cached_filter_data = get_cached_filters
    end

    def add_requester_filter
      email = params[:email]
      unless email.blank?
        requester = current_account.user_emails.user_for_email(email)
        @user_name = email
        unless requester.nil?
          params[:requester_id] = requester.id;
        else
          @response_errors = {:no_email => true}
        end
      end
      company_name = params[:company_name]
      unless company_name.blank?
        company = current_account.companies.find_by_name(company_name)
        unless(company.nil?)
          params[:company_id] = company.id
        else
          @response_errors = {:no_company => true}
        end
      end
    end

    def check_autorefresh_feature
      @is_auto_refresh_feature = current_account.auto_refresh_enabled?
    end

    def get_cached_filters
      tries = 3
      count = 0
      begin
        filters_str = get_tickets_redis_key("HELPDESK_TICKET_FILTERS:#{current_account.id}:#{current_user.id}:#{request.session_options[:id]}")
        Rails.logger.info "In get_cached_filters - filters_str : #{filters_str.inspect}"
        JSON.parse(filters_str) if filters_str
      rescue Exception => e
        NewRelic::Agent.notice_error(e, {:key => redis_key,
          :value => filters_str,
          :class => filters_str.class.name,
          :uri => request.url,
          :referer => request.referer,
          :count => count,
          :description => "Redis issue"})
        if count<tries
          count += 1
          retry
        else
          return
        end
      end
    end

    def report_ticket_filter
      begin
        key_args = { :account_id => current_account.id,
                     :user_id => current_user.id,
                     :session_id => request.session_options[:id],
                     :report_type => params[:report_type]
                   }
        reports_filters_str = get_tickets_redis_key(REPORT_TICKET_FILTERS % key_args)
        JSON.parse(reports_filters_str) if reports_filters_str
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
      end
    end

    def load_cached_ticket_filters
      if dashboard_filter?
        filter_params = {"unsaved_view" => true}
        action_hash = []
        TicketConstants::DASHBOARD_FILTER_MAPPING.each do |key,val|
            action_hash.push({ "condition" => val, "operator" => "is_in", "value" => params[key].to_s}) if params[key].present?
        end
        action_hash.push({ "condition" => "status", "operator" => "is_in", "value" => 0}) if params[:status].blank? and (params[:filter_name] != "new")
        if params[:filter_name].present?
          custom_tkt_filter = Helpdesk::Filters::CustomTicketFilter.new
          action_hash.push(custom_tkt_filter.default_filter(params[:filter_name])).flatten!
        end
        filter_params.merge!("data_hash" => action_hash.to_json)
        set_tickets_redis_key(redis_key,filter_params.to_json,86400)
        @cached_filter_data = get_cached_filters
        @cached_filter_data.symbolize_keys!
        handle_unsaved_view
        set_modes(action_hash)
        initialize_ticket_filter
        params.merge!(@cached_filter_data)
      elsif custom_filter?
        @cached_filter_data = report_filter? ? report_ticket_filter : get_cached_filters
        if @cached_filter_data
          @cached_filter_data.symbolize_keys!
          handle_unsaved_view
          initialize_ticket_filter
          params.merge!(@cached_filter_data)
        end
      else
        remove_tickets_redis_key(redis_key)
      end
    end

    def initialize_ticket_filter
       @ticket_filter = current_account.ticket_filters.new(Helpdesk::Filters::CustomTicketFilter::MODEL_NAME)
       @ticket_filter = @ticket_filter.deserialize_from_params(@cached_filter_data)
       #@ticket_filter.query_hash = JSON.parse(@cached_filter_data[:data_hash]) unless @cached_filter_data[:data_hash].blank?
    end

    def load_article_filter
      return if view_context.current_filter.to_s != 'article_feedback' || params[:article_id].present?
      params[:article_id] = get_tickets_redis_key(article_filter_key)
    end

    def save_article_filter
      set_tickets_redis_key(article_filter_key, params[:article_id]) if params[:filter_name] == 'article_feedback' && params[:article_id].present?
    end

    def article_filter_key
      (ARTICLE_FEEDBACK_FILTER % {
        :account_id => current_account.id,
        :user_id => current_user.id,
        :session_id => request.session_options[:id]
      })
    end

    def handle_unsaved_view
      unless @cached_filter_data[:unsaved_view].blank?
        params[:unsaved_view] = true
        @cached_filter_data.delete(:unsaved_view)
      end
    end

    def custom_filter?
      params[:filter_key].blank? and params[:filter_name].blank? and is_custom_filter_ticket?
    end

    def report_filter?
      !params[:report_type].blank?
    end

    def dashboard_filter?
      #(params[:filter_type] == "status") and params[:filter_key].present?
      TicketConstants::DASHBOARD_FILTER_MAPPING.keys.any? {|type| params[type].present?}
    end

    def is_custom_filter_ticket?
      params[:requester_id].blank? and params[:tag_id].blank? and params[:company_id].blank?
    end

    def load_ticket_filter
      return if @cached_filter_data
      filter_name = CGI.escapeHTML(view_context.current_filter)
      filter_name = current_account.sla_management_enabled? ? filter_name : fallback_filter_name(filter_name)
      if !is_num?(filter_name)
        load_default_filter(filter_name)
      else
        @ticket_filter = current_account.ticket_filters.find_by_id(filter_name)
        return load_default_filter(TicketsFilter::DEFAULT_FILTER) if @ticket_filter.nil? or !@ticket_filter.has_permission?(current_user)
        @ticket_filter.query_hash = @ticket_filter.data[:data_hash]
        set_modes(@ticket_filter.query_hash)
        params.merge!(@ticket_filter.attributes["data"])
      end
    end

    def load_default_filter(filter_name)
      params[:filter_name] = filter_name
      @ticket_filter = current_account.ticket_filters.new(Helpdesk::Filters::CustomTicketFilter::MODEL_NAME)
      @ticket_filter.query_hash = @ticket_filter.default_filter(filter_name)
      @ticket_filter.accessible = current_account.user_accesses.new
      @ticket_filter.accessible.visibility = Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me]
      set_modes(@ticket_filter.query_hash)
    end

    def fallback_filter_name(filter_name)
      ["overdue", "due_today"].include?(filter_name.to_s) ? "new_and_my_open" : filter_name
    end

    def set_modes(conditions)
      return unless current_account.shared_ownership_enabled?
      @agent_mode = TicketConstants::FILTER_MODES[:primary]
      @group_mode = TicketConstants::FILTER_MODES[:primary]
      conditions.each do |condition|
        if TicketConstants::SHARED_AGENT_COLUMNS_ORDER.include?(condition["condition"])
          @agent_mode = TicketConstants::SHARED_AGENT_COLUMNS_MODE_BY_NAME[condition["condition"]]
        elsif TicketConstants::SHARED_GROUP_COLUMNS_ORDER.include?(condition["condition"])
          @group_mode = TicketConstants::SHARED_GROUP_COLUMNS_MODE_BY_NAME[condition["condition"]]
        end
      end
    end

    def portal_check
      if !current_user.nil? and current_user.customer?
        load_ticket
      elsif !privilege?(:manage_tickets)
        access_denied
      end
    end

    def check_compose_feature
      access_denied unless current_account.compose_email_enabled?
    end

    def check_trial_outbound_limit
      if ((current_account.id > get_spam_account_id_threshold) && (!ismember?(SPAM_WHITELISTED_ACCOUNTS, current_account.id)))
        outbound_per_day_key = OUTBOUND_EMAIL_COUNT_PER_DAY % {:account_id => current_account.id }
        total_outbound_per_day = get_others_redis_key(outbound_per_day_key).to_i
        if (current_account.subscription.trial?)
          if (total_outbound_per_day >=5 )
            @outbound_limit_crossed = true
            flash.now[:error] = t(:'flash.general.outbound_limit_per_day_exceeded', :limit => get_trial_account_max_to_cc_threshold )
          end
        elsif(current_account.subscription.free?)
            if (total_outbound_per_day >= get_free_account_outbound_threshold )
              @outbound_limit_crossed = true
              flash.now[:error] = t(:'flash.general.outbound_limit_per_day_free_exceeded', :limit => get_free_account_outbound_threshold )
            end
        end
      end
    end

    def check_trial_customers_limit
      if ((current_account.id > get_spam_account_id_threshold) && (current_account.subscription.trial?) && (!ismember?(SPAM_WHITELISTED_ACCOUNTS, current_account.id)) && (Freemail.free?(current_account.admin_email)))
        if (@item.source == current_account.helpdesk_sources.ticket_source_keys_by_token[:outbound_email] || @item.source == current_account.helpdesk_sources.ticket_source_keys_by_token[:phone])
          if max_to_cc_threshold_crossed?
              flash[:error] = t(:'flash.general.recipient_limit_exceeded', :limit => get_trial_account_max_to_cc_threshold )
              redirect_to :back
          end
        end
      end
    end

    def max_to_cc_threshold_crossed?
      cc_emails = get_email_array(params[:cc_emails])
      to_email = get_email_array(params[:helpdesk_ticket][:email])
      total_recipients = cc_emails | to_email
      return (total_recipients.count  > get_trial_account_max_to_cc_threshold)
    end

    def build_ticket_body_attributes
      return render_500 if params[:helpdesk_ticket].nil?
      if params[:helpdesk_ticket][:description] || params[:helpdesk_ticket][:description_html]
        unless params[:helpdesk_ticket].has_key?(:ticket_body_attributes)
          ticket_body_hash = {:ticket_body_attributes => { :description => params[:helpdesk_ticket][:description],
                                  :description_html => params[:helpdesk_ticket][:description_html] }}
          params[:helpdesk_ticket].merge!(ticket_body_hash).tap do |t|
            t.delete(:description) if t[:description]
            t.delete(:description_html) if t[:description_html]
          end
        end
      end
    end

    def set_required_fields # validation
      if current_account.validate_required_ticket_fields?
        @item.required_fields = { :fields => current_account.ticket_fields_including_nested_fields.agent_required_fields,
                                  :error_label => :label }
      end
    end

    def verify_permission
      if @items.present?
        @item ||= @items.first
      end
      verified = true
      unless current_user && current_user.has_ticket_permission?(@item) && !@item.trashed
        verified = false
        flash[:notice] = t("flash.general.access_denied")
        if request.xhr? || is_native_mobile?
          if params[:action] = "show"
            params[:redirect] = "true"
          end
          render json: {access_denied: true}
        else
          redirect_to helpdesk_tickets_url
        end
      end
      verified
    end

    def verify_update_properties_permission
      unless current_user && current_user.has_ticket_permission?(@item) && !@item.trashed
        if request.xhr?
          params[:redirect] = "true"
        end
      end
    end

    def verify_ticket_permission_by_id
      ticket = current_account.tickets.find_by_id(params[:id])
      verify_ticket_permission(ticket)
    end

  def check_outbound_permission
    if @item.outbound_email?
      flash[:notice] = t("flash.general.access_denied")
      redirect_to helpdesk_tickets_url
    end
    true
  end

  def save_and_close?
    !params[:save_and_close].blank?
  end

  def notification_not_required?
    (!params[:save_and_close].blank?) || (params[:disable_notification] && params[:disable_notification].to_bool) ||
    (params[:action] == "quick_assign" && params[:assign] == "status" && params[:disable_notification] && params[:disable_notification].to_bool)
  end

  def check_ticket_status
    respond_to do |format|
      format.html{
        if !params["helpdesk_ticket"].nil? && params["helpdesk_ticket"]["status"].blank?
          flash[:error] = t("change_deleted_status_msg")
          redirect_to item_url
        end
      }
      format.any(:xml, :mobile, :json){
        params["helpdesk_ticket"]["status"] ||= @item.status unless params["helpdesk_ticket"].nil?
      }
    end
  end

  def handle_send_and_set
    @item.send_and_set = params[:send_and_set].present?
  end

  def empty_trash_key
    EMPTY_TRASH_TICKETS % {:account_id =>  current_account.id}
  end

  def empty_spam_key
    EMPTY_SPAM_TICKETS % {:account_id =>  current_account.id}
  end

  def set_selected_tab
    @selected_tab = :tickets
  end

  def validate_manual_dueby
    if(@item.manual_dueby && params[nscname].key?(:due_by) && params[nscname].key?(:frDueBy))
      unless validate_date(params[nscname][:due_by]) && validate_date(params[nscname][:frDueBy])
        respond_to do |format|
          format.json {
            render :json => { :update_failure => true, :errors => I18n.t('date_invalid') }.to_json and return
          }
          format.xml {
            render :xml => { :update_failure => true, :errors => I18n.t('date_invalid') }.to_xml and return
          }
          format.html { render :text => I18n.t('date_invalid') and return }
        end
      end
    else
      params[nscname].except!(:due_by, :frDueBy) unless params[nscname].nil?
    end
  end

  def validate_date(date_string)
    begin
      date = Date.parse(date_string)
    rescue
      return false
    end
  end
  def run_on_slave(&block)
    Sharding.run_on_slave(&block)
  end

  def run_on_db(&block)
    db_type = current_account.master_queries? ? :run_on_master : :run_on_slave
    Sharding.safe_send(db_type) do
      yield
    end
  end

  def load_sort_order
    params[:wf_order] = view_context.current_wf_order.to_s
    params[:wf_order_type] = view_context.current_wf_order_type.to_s
  end

  def load_ticket
    @ticket = @item = load_by_param(params[:id])
    load_or_show_error
  end

  def load_ticket_with_notes
    return load_ticket if request.format.html? or request.format.nmobile? or request.format.js?
    @ticket = @item = load_by_param(params[:id], preload_options)
    load_or_show_error(true)
  end

  def preload_options
    options = [:attachments, :note_body, :schema_less_note]
    include_options = {:notes => options}
    include_options
  end

  ### Methods for loading tickets from ES ###
  #
  def es_tickets_enabled?
    !params[:disable_es] and current_account.launched?(:es_tickets)
  end

  def load_filter_params
    cached_filter_data = @cached_filter_data.deep_symbolize_keys
    @ticket_filter = current_account.ticket_filters.new(Helpdesk::Filters::CustomTicketFilter::MODEL_NAME).deserialize_from_params(cached_filter_data)
    params.merge!(cached_filter_data)
    load_sort_order
  end

  def fetch_tickets(tkt=nil)
    if collab_filter_enabled_for?(view_context.current_filter)
      fetch_collab_tickets
    elsif es_tickets_enabled? and params[:html_format]
      #_Note_: Fetching from ES based on feature and only for web
      tickets_from_es(params)
    else
      if Account.current.customer_sentiment_ui_enabled?
        survey_association = Account.current.new_survey_enabled? ? "custom_survey_results" : "survey_results"
        current_account.tickets.preload({requester: [:avatar]}, :company, :schema_less_ticket, survey_association).permissible(current_user).filter(:params => params, :filter => 'Helpdesk::Filters::CustomTicketFilter')
      else
        current_account.tickets.preload({requester: [:avatar]}, :company).permissible(current_user).filter(:params => params, :filter => 'Helpdesk::Filters::CustomTicketFilter')
      end
    end
  end

  def tickets_from_es(params)
    es_options = {
      :page         => params[:page] || 1,
      :order_entity => params[:wf_order],
      :order_sort   => params[:wf_order_type]
    }
    Search::Tickets::Docs.new(@ticket_filter.query_hash.dclone).records('Helpdesk::Ticket', es_options)
  end

  def scenario_failure_notification
    message = if @valid_ticket.is_a? FalseClass
      log_error @item
      error_code = 1013
      I18n.t("helpdesk.flash.scenario_fail")
    else
      error_code = 1012
      I18n.t("admin.automations.failure")
    end
    flash[:notice] = render_to_string(:inline => message).html_safe
    respond_to do |format|
      format.html {
        redirect_to :back
      }
      format.js
      format.mobile {
        status = mobile_app_versioning? ? 400 : 200
        render :json => {
          :failure => true,
          :success => false,
          :error_code => error_code,
          :rule_name => message
        }.to_json, :status => status
      }
    end
  end

  def set_redirect_path
    if @item.related_ticket_ids.count == 1
      params[:redirect_to] = helpdesk_ticket_path(@item.associated_subsidiary_tickets("tracker").first)
    else
      params[:redirect_to] = helpdesk_tickets_path
    end
  end

  def link_to_tracker
    load_ticket
    @item.association_type = TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:related]
    @item.tracker_ticket_id = @tracker_ticket.display_id
    flash[:notice] = t(:'flash.tickets.link.success') if @item.save
  end

  def link_multiple
    return unless @tracker_ticket.tracker_ticket?
    if( (@tracker_ticket.related_tickets_count + params[:ids].count) <= TicketConstants::MAX_RELATED_TICKETS )
      Rails.logger.debug "Linking Related tickets [#{params[:ids]}] to tracker_ticket #{params[:tracker_id]}"
      ::Tickets::LinkTickets.perform_async({ :tracker_id => params[:tracker_id],
                :related_ticket_ids => params[:ids] })
      flash[:notice] = t(:'flash.tickets.link.delay_link',
            :tracker_ticket => params[:tracker_id],
            :tracker_ticket_subject => h(@tracker_ticket.subject)).html_safe
    else
      Rails.logger.debug "Count exceeded when linking[#{params[:ids]}] to tracker_ticket #{params[:tracker_id]}"
      remaining_count = TicketConstants::MAX_RELATED_TICKETS - @tracker_ticket.related_tickets_count
      if remaining_count > 0
        flash[:notice] = t("ticket.link_tracker.remaining_count", :count => remaining_count)
      else
        flash[:notice] = t("ticket.link_tracker.count_exceeded",:count => TicketConstants::MAX_RELATED_TICKETS)
      end
    end
  end

  def load_tracker_ticket
    @tracker_ticket = current_account.tickets.find_by_display_id(params[:tracker_id])
  end

  def associations_flash_text
    return unless @items.count == 1 && @items.first.linked_ticket?
    @items.first.tracker_ticket? ? t('ticket.link_tracker.tracker_delete_message') : t('ticket.link_tracker.related_delete_message')
  end

  def set_contact_validatable_custom_fields
    @requester.validatable_custom_fields = { :fields => current_account.contact_form.custom_contact_fields,
                                        :error_label => :label }
  end

  def set_company_validatable_custom_fields
    @company.validatable_custom_fields = { :fields => current_account.company_form.custom_company_fields,
                                        :error_label => :label }
  end

  def load_ticket_contact_data
    @company = @ticket.company
    @company_deleted = @ticket.owner_id.present? && @company.blank?
    @unassociated_company = @company.blank? ? false : @ticket.requester.companies.exclude?(@company)
  end

  def load_tkt_and_templates
    build_item
    construct_tkt
  end

  def child_tkt_post_persist
    if current_account.parent_child_tickets_enabled?
      if @item.child_ticket?
        params[:redirect_to] = params[:save_and_create] ?
        new_helpdesk_ticket_child_path(@item.assoc_parent_tkt_id) : helpdesk_ticket_path(@item.assoc_parent_tkt_id)
      elsif child_template_ids?
        initiate_child_creation
      end
    end
  end

  def initiate_child_creation
    params.merge!({:assoc_parent_id => @item.display_id})
    load_assoc_parent
    load_parent_template
    bulk_child_tkt_create
  end

  def load_associated_tickets
    if @item.assoc_parent_ticket? || @item.tracker_ticket?
      preload_models   = [:requester, :responder, :ticket_states, :ticket_status]
      conditions       = { display_id: @item.associates }
      per_page         = @item.assoc_parent_ticket? ? 10 : 30
      paginate_options = { :page => params[:page], :per_page => per_page }
      @associated_tickets = current_account.tickets.preload(preload_models).where(conditions).paginate(paginate_options) # rubocop:disable Gem/WillPaginate
    end
  end

  def can_close_assoc_parent? item = @item, oly_msg = false
    if item.assoc_parent_ticket? and item.validate_assoc_parent_tkt_status
      err_msg = I18n.t('ticket.unresolved_child')
      result = oly_msg ? (@status_err_msg = err_msg) : (item.errors.add(:base,
        err_msg) and return false)
    end
    true
  end

  def assign_parent_to_new_child
    construct_tkt
    all_attrs_from_parent.each { |key|
      next if key == "tags"
      value = prt_tkt_fd_value(key)
      @item.safe_send("#{key}=",value) }
    @all_attachments   = @assoc_parent_ticket.all_attachments
    @cloud_files       = @assoc_parent_ticket.cloud_files
    @item.requester_id = (@assoc_parent_ticket.responder_id.nil? ? @current_user.id :
      @assoc_parent_ticket.responder_id)
  end

  def check_ml_feature
    access_denied unless current_account.suggest_tickets_enabled?
  end

  def eligible_for_bulk?
    !mobile? && multiple_tickets?
  end

  def multiple_tickets?
    !params[:ids].nil?
  end

  def display_spam_flash
    msg1 = render_to_string(
      :inline => t("helpdesk.flash.spam",
                    :tickets => pluralize(@items.count, "ticket"),
                    :text => associations_flash_text,
                    :undo => "<%= link_to(t('undo'), { :action => :unspam, :ids => params[:ids] }, { :method => :put }) %>"
                )).html_safe

    link = render_to_string( :inline => "<%= link_to t('user_block'), block_user_path(:ids => @req_list), :method => :put, :remote => true  %>" ,
      :locals => { :req_list => @req_list.uniq } )

    notice_msg =  msg1
    notice_msg << " <br />#{t("block_users")} #{link}".html_safe if @req_list.present? and privilege?(:delete_contact)
    flash[:notice] =  notice_msg
    respond_to do |format|
      format.html { redirect_to redirect_url  }
      format.js
      format.mobile {  render :json => { :success => true , :success_message => t("helpdesk.flash.flagged_spam",
                    :tickets => get_updated_ticket_count,
                    :undo => "") }.to_json }
    end

  end

  def display_unspam_flash
    num_tickets = if params[:ids].present?
      @items.length == 1 ? "_single" : "_multiple"
    else
      ""
    end
    flash[:notice] = render_to_string(
      :inline => t("helpdesk.flash.flagged_unspam#{num_tickets}",
                      :tickets => pluralize(@items.count, "ticket") )).html_safe

    respond_to do |format|
      format.html { redirect_to (@items.length == 1) ? helpdesk_ticket_path(@items.first) : :back }
      format.js
    format.mobile {  render :json => { :success => true , :success_message => t("helpdesk.flash.flagged_unspam",
                     :tickets => get_updated_ticket_count) }.to_json }
    end
  end

  def display_destroy_flash
    respond_to do |expects|
      expects.html do
        flash[:notice] = render_to_string(
          :inline => t("helpdesk.flash.destroy",
                        :tickets => pluralize(@items.count, "ticket"),
                        :undo => "<%= link_to(t('undo'), { :action => :restore, :ids => params[:ids] }, { :method => :put }) %>"
                    )).html_safe
        redirect_to after_destroy_url
      end
      expects.mobile{
        render :json => {:success => true}
      }
      expects.nmobile{
        render :json => {:success => true}
      }
      expects.json  { render :json => :deleted}
      expects.js {
        process_destroy_message
        after_destroy_js
      }
      #until we impl query based retrieve we show only limited data on deletion.
      expects.xml{ render :xml => @items.to_xml(options)}
    end
  end

  def display_restore_flash
    respond_to do |result|
      result.html{
        num_tickets = if params[:ids].present?
          @items.length == 1 ? "_single" : "_multiple"
        else
          ""
        end
        flash[:notice] =  render_to_string(
          :inline => t("helpdesk.flash.flagged_restore#{num_tickets}",
                          :tickets => pluralize(@items.count, "ticket"))).html_safe
        redirect_to after_restore_url
      }
      result.mobile { render :json => { :success => true }}
      result.nmobile { render :json => { :success => true }}
      result.xml {  render :xml => @items.to_xml(options) }
      result.json {  render :json => @items.to_json(options) }
      result.js {
        flash[:notice] = render_to_string(
          :partial => '/helpdesk/shared/flash/restore_notice', :contacts => @items).html_safe
      }
    end
  end

  def req_list
    @req_list = []
    @items.each {|item| req = item.requester; @req_list << req.id if req.customer? }
  end

  def validate_ticket_close
    @failed_tickets = []
    load_items
    @items.each do |ticket|
      unless valid_ticket?(ticket)
        remove_from_params ticket
      end
    end
  end

  def validate_bulk_scenario
    @failed_tickets = []
    @va_rule = current_account.scn_automations.find_by_id(params[:scenario_id])
    if @va_rule.present? && @va_rule.visible_to_me?
      if actions_contains_close?
        load_items
        @items.each do |ticket|
          @va_rule.trigger_actions_for_validation(ticket, current_user)

          unless valid_ticket?(ticket)
            remove_from_params ticket
          end
        end
      end
    end
  end

  def validate_scenario
    @va_rule = current_account.scn_automations.find_by_id(params[:scenario_id])
    if @va_rule.present? && @va_rule.visible_to_me?
      @va_rule.trigger_actions_for_validation(@item, current_user)
      @valid_ticket = valid_ticket?(@item) if close_action?(@item.status)
    end
  end

  def actions_contains_close?
    status_action = @va_rule.action_data.find {|x| x.symbolize_keys!; x[:name] == 'status'}
    status_action && close_action?(status_action[:value].to_i)
  end

  def validate_quick_assign_close
    valid_ticket = (validate_ticket? && close_action?(params[:value].to_i)) ? valid_ticket?(@item) : true
    unless valid_ticket
      log_error @item
      @item_id_and_subject = [{:id => @item.id, :display_id => @item.display_id, :subject => CGI.escape_html(@item.subject)}]
      render :json => {
        :success => false,
        :message => render_to_string(
            :inline => t("helpdesk.flash.tickets_close_fail_on_quick_close",
            :tickets => 0,
            :failed_tickets => "<%= link_to( t('helpdesk.flash.tickets_failed', :failed_count => 1), '',  id: 'failed-tickets', 'data-tickets' => @item_id_and_subject.to_json, 'data-title' => t('helpdesk.flash.title_on_quick_close_fail'), 'data-description' => t('helpdesk.flash.description_on_quick_close_fail')) %>" ))}.to_json
    end
    valid_ticket
  end

  def export_limit_reached?
    if DataExport.ticket_export_limit_reached?(User.current)
      flash[:notice] = I18n.t('export_data.ticket_export.limit_reached', :max_limit => DataExport.ticket_export_limit)
      return redirect_to helpdesk_tickets_path
    end
  end

  def validate_ticket?
    params[:assign] == 'status' && !@item.deleted? && !@item.spam?
  end

  def remove_skill_param
    params[nscname].delete("skill_id")
  end

  def mobile_app_versioning?
    request.env["HTTP_REQUEST_ID"] && JSON.parse(request.env["HTTP_REQUEST_ID"])["api_version"].to_i == 1
  end

  def ios?
    request.env["HTTP_REQUEST_ID"] && JSON.parse(request.env["HTTP_REQUEST_ID"])["os_name"] == "iOS"
  end
end
