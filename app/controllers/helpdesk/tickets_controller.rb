class Helpdesk::TicketsController < ApplicationController

  require 'freemail'

  include ActionView::Helpers::TextHelper
  include ParserUtil
  include Redis::RedisKeys
  include Redis::OthersRedis
  include HelpdeskControllerMethods
  include Helpdesk::TicketActions
  include Search::TicketSearch
  include Helpdesk::Ticketfields::TicketStatus
  include Helpdesk::AdjacentTickets
  include Helpdesk::Activities
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
  include Helpdesk::Activities::ActivityMethods
  include Helpdesk::SpamAccountConstants

  before_filter :redirect_to_mobile_url
  skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:show,:suggest_tickets]
  before_filter :portal_check, :verify_format_and_tkt_id, :only => :show
  before_filter :check_compose_feature, :check_trial_outbound_limit, :only => :compose_email

  before_filter :find_topic, :redirect_merged_topics, :only => :new
  around_filter :run_on_slave, :only => [:user_ticket, :activities, :suggest_tickets]
  before_filter :save_article_filter, :only => :index
  around_filter :run_on_db, :only => [:custom_search, :index, :full_paginate]

  before_filter :set_mobile, :only => [ :index, :show,:update, :create, :execute_scenario, :assign, :spam , :update_ticket_properties , :unspam , :destroy , :pick_tickets , :close_multiple , :restore , :close ,:execute_bulk_scenario]
  before_filter :normalize_params, :only => :index
  before_filter :cache_filter_params, :only => [:custom_search]
  before_filter :load_cached_ticket_filters, :load_ticket_filter, :check_autorefresh_feature, :load_sort_order , :only => [:index, :filter_options, :old_tickets,:recent_tickets]
  before_filter :get_tag_name, :clear_filter, :only => :index
  before_filter :add_requester_filter , :only => [:index, :user_tickets]
  before_filter :load_filter_params, :only => [:custom_search], :if => :es_tickets_enabled?
  before_filter :load_article_filter, :only => [:index, :custom_search, :full_paginate]
  before_filter :disable_notification, :if => :notification_not_required?
  after_filter  :enable_notification, :if => :notification_not_required?
  before_filter :set_selected_tab

  layout :choose_layout

  before_filter :filter_params_ids, :only =>[:destroy,:assign,:close_multiple,:spam,:pick_tickets, :delete_forever, :delete_forever_spam, :execute_bulk_scenario, :unspam, :restore]
  before_filter :scoper_ticket_actions, :only => [ :assign,:close_multiple, :pick_tickets ]

  before_filter :load_items, :only => [ :destroy, :restore, :spam, :unspam, :assign,
    :close_multiple ,:pick_tickets, :delete_forever, :delete_forever_spam ]

  skip_before_filter :load_item
  alias :load_ticket :load_item

  before_filter :set_native_mobile, :only => [:show, :load_reply_to_all_emails, :index,:recent_tickets,:old_tickets , :delete_forever,:change_due_by,:reply_to_forward]
  before_filter :verify_ticket_permission_by_id, :only => [:component]

  before_filter :load_ticket,
    :only => [:edit, :update, :execute_scenario, :close, :change_due_by, :print, :clear_draft, :save_draft,
              :draft_key, :get_ticket_agents, :quick_assign, :prevnext, :status, :update_ticket_properties,
              :activities, :activitiesv2, :activities_all, :unlink, :related_tickets, :ticket_association, :suggest_tickets]
  before_filter :load_ticket_with_notes, :only => [:show]

  before_filter :check_outbound_permission, :only => [:edit, :update]

  skip_before_filter :build_item, :only => [:create, :compose_email]
  alias :build_ticket :build_item
  before_filter :build_ticket_body_attributes, :only => [:create]
  before_filter :build_ticket, :only => [:create, :compose_email]
  before_filter :set_required_fields, :check_trial_customers_limit, :only => :create

  before_filter :set_date_filter ,    :only => [:export_csv]
  before_filter :csv_date_range_in_days , :only => [:export_csv]
  before_filter :check_ticket_status, :only => [:update, :update_ticket_properties]
  before_filter :handle_send_and_set, :only => [:update_ticket_properties]
  before_filter :validate_manual_dueby, :only => :update
  before_filter :set_default_filter , :only => [:custom_search, :export_csv]

  before_filter :verify_permission, :only => [:show, :edit, :update, :execute_scenario, :close, :change_due_by, :print, :clear_draft, :save_draft,
              :draft_key, :get_ticket_agents, :quick_assign, :prevnext, :status, :update_ticket_properties, :activities, :unspam, :restore, :activitiesv2, :activities_all]

  before_filter :load_email_params, :only => [:show, :reply_to_conv, :forward_conv, :reply_to_forward]
  before_filter :load_conversation_params, :only => [:reply_to_conv, :forward_conv, :reply_to_forward]
  before_filter :load_reply_to_all_emails, :only => [:show, :reply_to_conv],
    :unless => lambda { |controller|
      controller.request.format.xml? or controller.request.format.json? or controller.request.format.mobile? }
  before_filter :load_note_reply_cc, :only => [:reply_to_forward]
  before_filter :load_note_reply_from_email, :only => [:reply_to_forward]
  before_filter :show_password_expiry_warning, :only => [:index, :show]
  before_filter :load_related_tickets, :only => [:related_tickets]
  before_filter :load_tracker_ticket, :only => [:link, :unlink]

  after_filter  :set_adjacent_list, :only => [:index, :custom_search]
  before_filter :fetch_item_attachments, :only => [:create, :update]
  before_filter :load_tkt_and_templates, :only => :apply_template
  before_filter :check_ml_feature, :only => [:suggest_tickets]

  
  def suggest_tickets
    tickets = []
    similar_tickets = get_similar_tickets
    tickets = current_account.tickets.visible.preload(:ticket_old_body).permissible(current_user).reorder("field(id,#{similar_tickets.join(',')})").where(id:similar_tickets) if similar_tickets.present?
    respond_to do |format|
      format.json do
        render :json => tickets
      end
    end
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
      body[:filter_condiiton] = {:group_id=>current_user.agent_groups.pluck(:group_id),:responder_id=> [current_user.id]}
    elsif current_user.assigned_ticket_permission
       body[:filter_condiiton] = {:responder_id => [current_user.id]}
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

  def index
    #For removing the cookie that maintains the latest custom_search response to be shown while hitting back button
    params[:html_format] = request.format.html?
    tkt = current_account.tickets.permissible(current_user)
    @items = fetch_tickets unless is_native_mobile?
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
        unless request.headers['X-PJAX']
          # Bad code need to rethink. Pratheep
          @show_options = show_options
        end
        @current_view = @ticket_filter.id || @ticket_filter.name if is_custom_filter_ticket?
        flash[:notice] = t(:'flash.tickets.empty_trash.delay_delete') if @current_view == "deleted" and key_exists?(empty_trash_key)
        flash[:notice] = t(:'flash.tickets.empty_spam.delay_delete') if @current_view == "spam" and key_exists?(empty_spam_key)
        @is_default_filter = (!is_num?(view_context.current_filter))
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
          @items.preload(:ticket_old_body,:schema_less_ticket,:flexifield => :flexifield_def).each { |tic|
            array << tic.as_json({}, false)['helpdesk_ticket']
          }
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
    render :partial => "helpdesk/shared/filter_options", :locals => { :current_filter => @ticket_filter , :shared_ownership_enabled => current_account.features?(:shared_ownership)}
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
    conditions_hash = query_hash.map{|i|{ i["condition"] => i["value"] }}.inject({}){|h, e|h.merge! e}
    meta_data       = filters_meta_data(conditions_hash) if conditions_hash.keys.any? {|k| META_DATA_KEYS.include?(k.to_s)}
    render :json => { :conditions => conditions_hash,
                      :default => is_default_filter,
                      :meta_data => meta_data
                    }
  end
  
  def invalid_custom_filter?(filter_name)
    @ticket_filter = current_account.ticket_filters.find_by_id(filter_name)
    @ticket_filter.nil? || !@ticket_filter.has_permission?(current_user)
  end

  def latest_ticket_count # Possible dead code
    index_filter =  current_account.ticket_filters.new(Helpdesk::Filters::CustomTicketFilter::MODEL_NAME).deserialize_from_params(params)
    ticket_count =  current_account.tickets.permissible(current_user).latest_tickets(params[:latest_updated_at]).count(:id, :conditions=> index_filter.sql_conditions)

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
    @current_view = view_context.current_filter
    render :partial => "custom_search"
  end

  def show
    @to_emails = @ticket.to_emails

    draft_hash = get_tickets_redis_hash_key(draft_key)
    @draft = draft_hash ? draft_hash["draft_data"] : ""

    @subscription = current_user && @item.subscriptions.find(
      :first,
      :conditions => {:user_id => current_user.id})

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
        @last_broadcast_note = run_on_slave { @ticket.notes.last_broadcast_note.first } if @ticket.related_ticket?
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
        hash.merge!({:last_reply => bind_last_reply(@ticket, @signature, false, true, true)})
        hash.merge!({:last_forward => bind_last_conv(@ticket, @signature, true)})
        hash.merge!({:ticket_properties => ticket_props})
        hash.merge!({:reply_template => parsed_reply_template(@ticket,nil)})
        hash.merge!({:default_twitter_body_val => default_twitter_body_val(@ticket)}) if @item.twitter?
        hash.merge!({:twitter_handles_map => twitter_handles_map}) if @item.twitter?
        hash.merge!({:tags => @item.tags.map(&:to_mob_json)})
        hash.merge!(@ticket_notes[0].to_mob_json) unless @ticket_notes[0].nil?
        render :json => hash
      }
      format.mobile {
		 render :json => @item.to_mob_json
	  }
    end
  end

  def prevnext
    @previous_ticket = find_adjacent(:prev)
    @next_ticket = find_adjacent(:next)
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
          result = {:errors=>@item.errors.full_messages }
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

  def update_requester
    @ticket = load_by_param(params[:id])
    @requester_errors = false
    @company_name_required_error = false

    requester = current_account.users.find_by_id(params["requester_widget"]["contact_id"])

    if requester.present? && requester.customer?
      requester.validatable_custom_fields = { :fields => current_account.contact_form.custom_contact_fields,
                                          :error_label => :label }
      if params["company"].present? && requester.company.present?
        @company = current_account.companies.find(requester.company_id)
        @company.validatable_custom_fields = { :fields => current_account.company_form.custom_company_fields, 
                                               :error_label => :label }
        check_domain_exists unless @company.update_attributes(params["company"])
        flash[:notice] = activerecord_error_list(@company.errors) unless @existing_company.present?
      end

      if (@company.blank? || @company.errors.blank?)
        flash[:notice] = requester.update_attributes(params["contact"]) ? 
          t(:'flash.general.update.success', :human_name => t('requester_widget_human_name')) :
          activerecord_error_list(requester.errors)
      else
        @requester_errors = true
      end

    end

    # if company name editing is allowed, enable the following block and remove the block above

    # if requester.present? && requester.customer?
    #   requester.validatable_custom_fields = { :fields => current_account.contact_form.custom_contact_fields,
    #                                       :error_label => :label }
    #   params[:contact][:customer_id] = ""

    #   if company_details_present?
    #     if params["company"]["name"].present?
    #       @company = current_account.companies.find_by_name(params["company"]["name"])
    #       if @company
    #         @company.assign_attributes(params["company"])
    #       else
    #         @company = current_account.companies.new(params["company"])
    #       end
    #       @company.validatable_custom_fields = { :fields => current_account.company_form.custom_company_fields,
    #                                              :error_label => :label }
    #       check_domain_exists unless @company.save
    #       flash[:notice] = activerecord_error_list(@company.errors) unless @existing_company.present?
    #       params[:contact][:customer_id] = @company.id
    #     else
    #       @company_name_required_error = true
    #     end
    #   end
    #   if (@company.blank? || @company.errors.blank?) && !@company_name_required_error
    #     if requester.update_attributes(params["contact"])
    #       flash[:notice] = t(:'flash.general.update.success', :human_name => t('requester_widget_human_name'))
    #     else
    #       check_company_association_exists(requester.errors)
    #       flash[:notice] = activerecord_error_list(requester.errors) unless @company_association_exists
    #     end
    #   else
    #     @requester_errors = true
    #   end
    # end
  end

  def assign
    user = params[:responder_id] ? User.find(params[:responder_id]) : current_user
    assign_ticket user

    flash[:notice] = render_to_string(
      :inline => t("helpdesk.flash.assignedto", :tickets => get_updated_ticket_count,
                                                :username => user.name ))


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
    end

  end

  def close_multiple
    status_id = CLOSED
    @items.each do |item|
      item.update_attributes(:status => status_id)
    end

    respond_to do |format|
      format.html {
        flash[:notice] = render_to_string(
            :inline => t("helpdesk.flash.tickets_closed", :tickets => get_updated_ticket_count ))
          redirect_to helpdesk_tickets_path
        }
        format.xml {  render :xml =>@items.to_xml({:basic=>true}) }
        format.mobile { render :json => { :success => true , :success_message => t("helpdesk.flash.tickets_closed",
                                          :tickets => get_updated_ticket_count )}.to_json }
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
    va_rule = current_account.scn_automations.find_by_id(params[:scenario_id])
    if va_rule.present? and va_rule.visible_to_me? and va_rule.check_user_privilege
      Tickets::BulkScenario.perform_async({:ticket_ids => params[:ids], :scenario_id => params[:scenario_id]})
      va_rule.fetch_actions_for_flash_notice(current_user)
      actions_executed = Va::RuleActivityLogger.activities
      Va::RuleActivityLogger.clear_activities
      respond_to do |format|
        format.html {
          flash[:notice] = render_to_string(:partial => '/helpdesk/tickets/execute_scenario_notice',
                                        :locals => { :actions_executed => actions_executed, :rule_name => va_rule.name, :bulk_scenario => true, :count => params[:ids].length }).html_safe
            redirect_to :back
          }
      end
    else
      scenario_failure_notification
    end
  end

  def execute_scenario
    va_rule = current_account.scn_automations.find_by_id(params[:scenario_id])
    if va_rule.present? and va_rule.visible_to_me? and va_rule.trigger_actions(@item, current_user)
      @item.save
      @item.create_scenario_activity(va_rule.name)
      @va_rule_executed = va_rule
      actions_executed = Va::RuleActivityLogger.activities
      Va::RuleActivityLogger.clear_activities
      respond_to do |format|
        format.html {
          flash[:notice] = render_to_string(:partial => '/helpdesk/tickets/execute_scenario_notice',
                                        :locals => { :actions_executed => actions_executed, :rule_name => va_rule.name }).html_safe
          redirect_to :back
        }
        format.xml { render :xml => @item }
        format.mobile {
          render :json => {:success => true, :id => @item.id, :actions_executed => actions_executed, :rule_name => va_rule.name , :success_message => t("activities.tag.execute_scenario", :rule_name => va_rule.name) }.to_json
        }
        format.json { render :json => @item }
        format.js {
          flash[:notice] = render_to_string(:partial => '/helpdesk/tickets/execute_scenario_notice',
                                        :locals => { :actions_executed => actions_executed, :rule_name => va_rule.name }).html_safe
        }
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
    req_list = []
    @items.each do |item|
      item.spam = true
      req = item.requester
      req_list << req.id if req.customer?
      store_dirty_tags(item)
      item.save

      Search::RecentTickets.new(item.display_id).delete if item.is_a?(Helpdesk::Ticket)      
    end

    msg1 = render_to_string(
      :inline => t("helpdesk.flash.spam",
                      :tickets => get_updated_ticket_count,
                      :text => associations_flash_text,
                      :undo => "<%= link_to(t('undo'), { :action => :unspam, :ids => params[:ids] }, { :method => :put }) %>"
                  )).html_safe

    link = render_to_string( :inline => "<%= link_to t('user_block'), block_user_path(:ids => req_list), :method => :put, :remote => true  %>" ,
      :locals => { :req_list => req_list.uniq } )

    notice_msg =  msg1
    notice_msg << " <br />#{t("block_users")} #{link}".html_safe unless req_list.blank?

    flash[:notice] =  notice_msg
    respond_to do |format|
      format.html { redirect_to redirect_url  }
      format.js
      format.mobile {  render :json => { :success => true , :success_message => t("helpdesk.flash.flagged_spam",
                      :tickets => get_updated_ticket_count,
                      :undo => "") }.to_json }
    end
  end

  def unspam
    @items.each do |item|
      item.spam = false
      restore_dirty_tags(item)
      item.save
      #mark_requester_deleted(item,false)
    end

    flash[:notice] = render_to_string(
      :inline => t("helpdesk.flash.flagged_unspam",
                      :tickets => get_updated_ticket_count )).html_safe

    respond_to do |format|
      format.html { redirect_to (@items.size == 1) ? helpdesk_ticket_path(@items.first) : :back }
      format.js
	  format.mobile {  render :json => { :success => true , :success_message => t("helpdesk.flash.flagged_unspam",
                     :tickets => get_updated_ticket_count) }.to_json }
    end
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
    @last_broadcast_note = run_on_slave { @ticket.notes.last_broadcast_note.first } if @ticket.related_ticket?
    respond_to do |format|
      format.html { render :partial => "/helpdesk/tickets/show/ticket_association", :locals => { :ticket => @ticket } }
    end
  end

  def related_tickets
    if params[:page].present?
      render( :partial => "helpdesk/tickets/show/related_ticket", 
                    collection: @related_tickets)
    else
      render :partial => "helpdesk/tickets/show/related_tickets_container"
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
        @item.send( params[:assign] + '=' ,  params[:value]) if @item.respond_to?(params[:assign])
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
    build_tkt_body
    if params['format'] == 'widget'
      render :layout => 'widgets/contacts'
    end
  end

  def create
    if (!params[:topic_id].blank? && find_topic) && (@topic.ticket.nil? || (@topic.ticket.present? && @topic.ticket.deleted))
      @item.source = Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:forum]
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
    if @item.save_ticket
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
      puts "Time format mismatch. Start time and end time should be like #{Time.now.to_formatted_s(:db)}"
    ensure
      # Reset to previous TZ:
      Time.zone = old_tz
    end
    time
  end

  def close
    status_id = CLOSED
    #@old_timer_count = @item.time_sheets.timer_active.size - will enable this later..not a good solution
    if @item.update_attributes(:status => status_id)
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
    sol_desc = current_account.solution_article_meta.find(params[:id]).send("#{language.to_key}_article")
    render :text => Helpdesk::HTMLSanitizer.sanitize_for_insert_solution(sol_desc.description) || ""
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
    begin
      params[:draft_data] = Helpdesk::HTMLSanitizer.clean(params[:draft_data])
      draft_cc = fetch_valid_emails(params[:draft_cc]).map {|e| "#{e};"}.to_s.sub(/;$/,"")
      draft_bcc = fetch_valid_emails(params[:draft_bcc]).map {|e| "#{e};"}.to_s.sub(/;$/,"")
      draft_hash_data = {
        "draft_data" => params[:draft_data],
        "draft_cc" => draft_cc,
        "draft_bcc" => draft_bcc
      }
      set_tickets_redis_hash_key(draft_key, draft_hash_data)
    rescue Exception => e
      NewRelic::Agent.notice_error(e,{:key => draft_key,
        :value => params[:draft_data],
        :description => "Redis issue",
        :count => count})
      if count<tries
          count += 1
          retry
      end
    end
    render :nothing => true
  end

  def clear_draft
    remove_tickets_redis_key(draft_key)
    render :nothing => true
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
    if Account.current.launched?(:activity_ui) and Account.current.features?(:activity_revamp) and request.format != "application/json" and ACTIVITIES_ENABLED
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
      if Account.current.features?(:activity_revamp)
        params[:event_type] = ::HelpdeskActivities::EventType::ALL
        params[:limit]      = 200
        activities = new_activities(params, @item, :test_json)
      end
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
      recent_templ = fetch_templates(["`ticket_templates`.id IN (?)",recent_ids], recent_ids, RECENT_TEMPLATES)
    else
      recent_ids   = ""
      recent_templ = []
    end
    size = ITEMS_TO_DISPLAY - recent_templ.count
    acc_templ = fetch_templates(["`ticket_templates`.id NOT IN (?)",recent_ids],nil, size, recent_ids)
    render :json => { :all_acc_templates => acc_templ, :recent_templates => recent_templ }
  end

  def search_templates
    search_acc_templ = fetch_templates(["`ticket_templates`.name like ?","%#{params[:search_string]}%"])
    render :json => { :all_acc_templates => search_acc_templ }
  end

  def apply_template
    @template  = current_account.ticket_templates.find_by_id(params[:template_id])
    @template  = nil unless @template and @template.visible_to_me?

    if @template.present?
      @all_attachments = @template.all_attachments
      @cloud_files = @template.cloud_files
      @template.template_data.each do |key,value|
        next if compose_email? && invisible_fields?(key)
        key == "tags" ? (@item[key] = value) : (@item.send("#{key}=",value))
      end
    else
      flash[:notice] = t('ticket_templates.not_available')
    end
    respond_to do |format|
      format.js { render :partial => "/helpdesk/tickets/apply_template" }
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
        pluralize(@items.length, t('ticket_was'), t('tickets_were'))
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
    @signature = current_user.agent.parsed_signature('ticket' => @ticket, 'helpdesk_name' => @ticket.account.portal_name)
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

    def set_trashed_column
      sql_array = ["update helpdesk_schema_less_tickets st inner join helpdesk_tickets t on
                    st.ticket_id= t.id and st.account_id=%s and t.account_id=%s
                    set st.%s = 1 where t.id in (%s)",
                    current_account.id, current_account.id, Helpdesk::SchemaLessTicket.trashed_column, @items.map(&:id).join(',')]
      sql = ActiveRecord::Base.send(:sanitize_sql_array, sql_array)

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

    def scoper_ticket_actions
      # check for mobile can be removed when mobile apps perform bulk actions as background job
      if  !mobile?  and (params[:ids] and params[:ids].length > BACKGROUND_THRESHOLD)
        ticket_actions_background
      end
    end

    def params_for_bulk_action
      params.slice('ids','responder_id')
    end

    def ticket_actions_background
      args = { :action => action_name }
      args.merge!(params_for_bulk_action)
      Tickets::BulkTicketActions.perform_async(args)
      respond_to do |format|
        format.html {
          flash[:notice] = t('helpdesk.flash.tickets_background')
          redirect_to helpdesk_tickets_path
        }
      end
    end

    def find_topic
    	@topic = current_account.topics.find(:first, :conditions => {:id => params[:topic_id]}) unless params[:topic_id].nil?
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
      @is_auto_refresh_feature = current_account.features?(:auto_refresh)
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

    def dashboard_filter_redis_key
      key = {
              :account_id => current_account.id,
              :user_id => current_user.id,
              :session_id => request.session_options[:id]
            }
      DASHBOARD_TABLE_FILTER_KEY % key
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

    def set_modes(conditions)
      return unless current_account.features?(:shared_ownership)
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
      if ((current_account.id > get_spam_account_id_threshold) && (current_account.subscription.trial?) && (!ismember?(SPAM_WHITELISTED_ACCOUNTS, current_account.id)))
        outbound_per_day_key = OUTBOUND_EMAIL_COUNT_PER_DAY % {:account_id => current_account.id }
        total_outbound_per_day = get_others_redis_key(outbound_per_day_key).to_i
        if (total_outbound_per_day >=5 )
          @outbound_limit_crossed = true
          flash.now[:error] = t(:'flash.general.outbound_limit_per_day_exceeded', :limit => get_trial_account_max_to_cc_threshold )
        end
      end
    end

    def check_trial_customers_limit
      if ((current_account.id > get_spam_account_id_threshold) && (current_account.subscription.trial?) && (!ismember?(SPAM_WHITELISTED_ACCOUNTS, current_account.id)) && (Freemail.free?(current_account.admin_email)))
        if (@item.source == Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:outbound_email] || @item.source == Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:phone])
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
    db_type = current_account.slave_queries? ? :run_on_slave : :run_on_master
    Sharding.send(db_type) do
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

  def load_or_show_error(load_notes = false)
    return redirect_to support_ticket_url(@ticket) if @ticket and current_user.customer?
    helpdesk_restricted_access_redirection(@ticket, 'flash.agent_as_requester.ticket_show') if @ticket and @ticket.restricted_in_helpdesk?(current_user)
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

  def preload_options
    options = [:attachments, :note_old_body, :schema_less_note]
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
    #_Note_: Fetching from ES based on feature and only for web
    if es_tickets_enabled? and params[:html_format]
      tickets_from_es(params)
    else
      current_account.tickets.preload({requester: [:avatar]}, :company).permissible(current_user).filter(:params => params, :filter => 'Helpdesk::Filters::CustomTicketFilter')
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
    flash[:notice] = I18n.t("admin.automations.failure")
    respond_to do |format|
      format.html {
        redirect_to :back
      }
      format.js
      format.mobile {
        render :json => { :failure => true,
           :rule_name => I18n.t("admin.automations.failure") }.to_json
      }
    end
  end

  def set_redirect_path
    if @item.related_ticket_ids.count == 1
      params[:redirect_to] = helpdesk_ticket_path(@item.related_tickets.first)
    else 
      params[:redirect_to] = helpdesk_tickets_path
    end
  end

  def load_related_tickets
    if @item.tracker_ticket?
      preload_models = [:requester, :responder, :ticket_states, :ticket_status]
      conditions = { display_id: @item.associates }
      paginate_options = { :page => params[:page], :per_page => 30 }
      @related_tickets = current_account.tickets.preload(preload_models).where(conditions).paginate(paginate_options)
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

  def check_domain_exists
      if @company.errors[:"company_domains.domain"].include?("has already been taken")
        @company.company_domains.each do |cd|
          @existing_company ||= current_account.company_domains.find_by_domain(cd.domain).try(:company) if cd.new_record?
        end
      end
  end

  def check_company_association_exists errors
    if errors[:"default_user_company.company_id"].include?("has already been taken")
      @company_association_exists = true
      @requester_errors = true
    end
  end

  def flat_hash(hash_to_convert,tmp=[],new_hash={})
    return new_hash.update({ tmp=>hash_to_convert }) unless hash_to_convert.is_a? Hash
    hash_to_convert.each { |k,v| flat_hash(v,tmp+[k],new_hash) }
    new_hash
  end


  def company_details_present?
    company_hash = flat_hash(params["company"])
    company_hash.values.any?{|v| !v.nil? && v.length > 0 && v != "false"}
  end


  def load_tkt_and_templates
    build_item
    @item.build_flexifield
    @item.ff_def = Account.current.flexi_field_defs.first.id
    build_tkt_body
  end

  def build_tkt_body
    @item.build_ticket_body
    source = compose_email? ? :outbound_email : :phone
    @item.source = Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[source]
  end

  def compose_email?
    params[:action].eql?("compose_email") or params[:template_form].eql?("compose_email")
  end

  def invisible_fields? key
    ["product_id", "responder_id", "source"].include?(key.to_s)
  end

  def recent_templ_ids
    if params[:recent_ids]
      recent_ids = ActiveSupport::JSON.decode(params[:recent_ids])
      recent_ids.compact!
      recent_ids
    end
  end

  def check_ml_feature
    access_denied unless current_account.suggest_tickets_enabled? 
  end

end
