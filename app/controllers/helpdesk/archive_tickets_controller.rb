class Helpdesk::ArchiveTicketsController < ApplicationController
  include Search::TicketSearch
  include Helpdesk::Activities
  include Helpdesk::Activities::ActivityMethods
  include Helpdesk::AdjacentArchiveTickets
  include Support::TicketsHelper
  include ExportCsvUtil
  include Helpdesk::NotePropertiesMethods
  include AdvancedTicketScopes
  helper AutocompleteHelper
  helper Helpdesk::ArchiveNotesHelper
  helper Helpdesk::RequesterWidgetHelper

  around_filter :run_on_slave
  before_filter :check_feature
  before_filter :redirect_old_ui_routes, only: [:index, :show, :new, :edit]
  before_filter :get_tag_name, :only => :index
  before_filter :set_filter_options, :set_data_hash, :load_sort_order, :only => [ :index, :custom_search ]
  before_filter :load_ticket, :verify_permission, :load_reply_to_all_emails, :only => [:activities, :prevnext, :activitiesv2]
  before_filter :set_all_agent_groups_permission, only: [:print_archive]
  before_filter :verify_format_and_tkt_id, :load_ticket_with_notes, :verify_permission, :load_reply_to_all_emails, :only => [:show,:print_archive]
  before_filter :set_date_filter, :only => [:export_csv]
  before_filter :csv_date_range_in_days , :only => [:export_csv]
  before_filter :set_selected_tab  
  before_filter :export_limit_reached? , :only => [:export_csv]

  after_filter  :set_adjacent_list, :only => [:index, :custom_search]
  layout :choose_layout

  def index
    @items = current_account.archive_tickets.preload({requester: [:avatar]}, :company).permissible(current_user).filter(:params => params, 
      :filter => 'Helpdesk::Filters::ArchiveTicketFilter')
    
    respond_to do |format|
      format.html do
        @current_options = params
        @show_options = archive_show_options 
      end
      format.json do
        unless @response_errors.nil?
          render :json => {:errors => @response_errors}.to_json
        else
          array = []
          @items.preload(:archive_ticket_association).each { |tic| 
            array << tic.as_json({}, false)['helpdesk_archive_ticket']
          }
          render :json => array
        end
      end
      format.xml do
        render :xml => @response_errors.nil? ? @items.to_xml({:shallow => true}) : 
        @response_errors.to_xml(:root => 'errors')
      end
    end
  end

  def custom_search
    @items = current_account.archive_tickets.preload({requester: [:avatar]}, :company).permissible(current_user).filter(:params => params, 
      :filter => 'Helpdesk::Filters::ArchiveTicketFilter')
    
    respond_to do |format|
      format.js {}
    end
  end

  def show
    @to_emails = @ticket.to_emails
    @page_title = %([##{@ticket.display_id}] #{@ticket.subject})
    
    # Only store recent tickets in redis which are not spam or not deleted
    Search::RecentTickets.new(@ticket.display_id).store unless @ticket.spam || @ticket.deleted

    respond_to do |format|
      format.html  {
        @ticket_notes = @ticket_notes.reverse
        @ticket_notes_total = @ticket.conversation_count
        build_notes_last_modified_user_hash(@ticket_notes)
      }      
      format.json {
        render :json => @item.to_json
      }
      format.xml  { 
        render :xml => @item.to_xml  
      }
    end
  end

  def latest_note
    ticket = current_account.archive_tickets.permissible(current_user).find_by_id(params[:id])
    if ticket.nil?
      render :text => t("flash.general.access_denied")
    else
      render :partial => "/helpdesk/archive_tickets/ticket_overlay", :locals => {:ticket => ticket}
    end
  end

  def full_paginate
    render 'no_paginate' 
  end 

  def configure_export
    @csv_headers = export_fields(false)
    render :partial => "configure_export"
  end
  
  def export_csv
    params[:portal_url] = main_portal? ? current_account.host : current_portal.portal_url
    Export::Ticket.enqueue(params)
    flash[:notice] = t("export_data.ticket_export.info")
    redirect_to helpdesk_archive_tickets_path
  end

  def activities
    return activity_json if request.format == "application/json"
    options = [:user => :avatar]
    if params[:since_id].present?
      activity_records = @item.activities.archive_tickets_activity_since(params[:since_id]).includes(options)
    elsif params[:before_id].present?
      activity_records = @item.activities.archive_tickets_activity_before(params[:before_id]).includes(options)
    else
      activity_records = @item.activities.newest_first.includes(options).first(3)
    end
    
    @activities = stacked_activities(@item, activity_records.reverse, true)
    
    # Omitting the Ticket Creation activity as in helpdesk/ticket_activities.rb
    @total_activities =  @item.activities.size - 1 

    if params[:since_id].present? or params[:before_id].present?
      render :partial => "helpdesk/archive_tickets/show/activity.html.erb", :collection => @activities
    else
      render :layout => false
    end
  end

  def activitiesv2
    if request.format != "application/json" && ACTIVITIES_ENABLED
      type = :tkt_activity
      @activities_data = new_activities(params, @item, type, true)
      @total_activities  ||=  @activities_data[:total_count] 
      respond_to do |format|
        format.html{
           if  @activities_data.nil? || @activities_data[:error].present?
            render nothing: true
          else
            @activities = @activities_data[:activity_list].reverse
            if params[:since_id].present? or params[:before_id].present?
               render :partial => "helpdesk/archive_tickets/show/custom_activity.html.erb", :collection => @activities
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

  def component
    @ticket = current_account.archive_tickets.find_by_id(params[:id])   
    render :partial => "helpdesk/tickets/show/#{params[:component]}", 
            :locals => { :ticket => @ticket , :search_query =>params[:q] } 
  end

  def prevnext
    @previous_ticket = find_adjacent(:prev)
    @next_ticket = find_adjacent(:next)
  end

  def get_tag_name
    if params[:tag_id].present?
      tag = Helpdesk::Tag.find_by_id(params[:tag_id])
      params[:tag_name] = tag.name if tag
    end
  end
  private
    def set_filter_options
      @filters_options = scoper_user_filters.map { |i| {:id => i[:id], :name => i[:name], :default => false, :user_id => i.accessible.user_id} }
    end

    def scoper_user_filters
      current_account.ticket_filters.my_ticket_filters(current_user)
    end

    def load_ticket
      load_or_show_error
    end

    def load_ticket_with_notes
      request.format.html? ? load_or_show_error : load_or_show_error(true)
    end

    def load_or_show_error(load_notes = false)
      options = load_notes ? archive_preload_options : {}
      @ticket = @item = current_account.archive_tickets.find_by_param(params[:id], current_account, options)

      if @ticket and @ticket.restricted_in_helpdesk?(current_user)
        view_on_portal_msg = I18n.t('flash.agent_as_requester.view_ticket_on_portal', :support_ticket_link => @item.support_ticket_path)
        redirect_msg =  "#{I18n.t('flash.agent_as_requester.ticket_show')} #{view_on_portal_msg}".html_safe
        flash[:notice] = redirect_msg
        redirect_to helpdesk_archive_tickets_url 
      end

      @item || raise(ActiveRecord::RecordNotFound)
    end

    def load_sort_order
      params[:wf_order] = Helpdesk::ArchiveTicket.sort_fields_options_array.include?(view_context.current_wf_order) ? view_context.current_wf_order.to_s : "created_at"
      params[:wf_order_type] = view_context.current_wf_order_type.to_s
    end

    def verify_permission
      has_permission = (advanced_scope_enabled? && action == :print_archive) ? current_user.has_read_ticket_permission?(@item) : current_user.has_ticket_permission?(@item) if current_user
      unless current_user && has_permission
        flash[:notice] = t("flash.general.access_denied") 
        if params['format'] == "widget"
          return false
        elsif request.xhr?
          params[:redirect] = "true"
        else
          redirect_to helpdesk_archive_tickets_url
        end
      end
      true
    end

    def load_reply_to_all_emails
      default_notes_count = "nmobile".eql?(params[:format])? 1 : 3
      @ticket_notes = @ticket.conversation(nil, default_notes_count)
    end

    def set_selected_tab
      @selected_tab = :tickets
    end

    def set_data_hash
      if params[:requester_id]
        params[:data_hash] = ActiveSupport::JSON.encode [{"operator"=>"is_in", 
                              "condition"=>"requester_id", "value"=> params[:requester_id] }]
      elsif params[:tag_name]
        params["helpdesk_tags.name"] = params[:tag_name]
        params[:data_hash] = ActiveSupport::JSON.encode [{"operator"=>"is_in",
                              "condition"=>"helpdesk_tags.name", "value"=> params[:tag_name] }]
      elsif params[:company_id]
        params["owner_id"] = params[:company_id]
        params[:data_hash] = ActiveSupport::JSON.encode [{"operator"=>"is_in", 
                              "condition"=>"owner_id", "value"=> params[:company_id] }]
    end
  end

  def check_feature
    unless current_account.features_included?(:archive_tickets)
      redirect_to helpdesk_tickets_url
    end
  end

  def export_limit_reached?
    if DataExport.archive_ticket_export_limit_reached?
      flash[:notice] = I18n.t('export_data.archive_ticket_export.limit_reached', :max_limit => DataExport.archive_ticket_export_limit)
      return redirect_to helpdesk_archive_tickets_path
    end
  end

  def run_on_slave(&block)
    Sharding.run_on_slave(&block)
  end 

  def choose_layout
      layout_name = request.headers['X-PJAX'] ? 'maincontent' : 'application'
      case action_name
        when "print_archive"
          layout_name = 'print'
      end
      layout_name
  end
end