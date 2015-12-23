class Helpdesk::ArchiveTicketsController < ApplicationController
  include Search::TicketSearch
  include Helpdesk::Activities
  include Helpdesk::AdjacentArchiveTickets
  include Support::TicketsHelper
  include ExportCsvUtil
  helper AutocompleteHelper

  around_filter :run_on_slave
  before_filter :check_feature
  
  before_filter :set_filter_options, :set_data_hash, :load_sort_order, :only => [ :index, :custom_search ]
  before_filter :load_ticket, :verify_permission, :load_reply_to_all_emails, :only => [:show, :activities, :prevnext]
  before_filter :set_date_filter, :only => [:export_csv]
  before_filter :csv_date_range_in_days , :only => [:export_csv]
  before_filter :set_selected_tab  

  after_filter  :set_adjacent_list, :only => [:index, :custom_search]

  def index
    @items = current_account.archive_tickets.permissible(current_user).filter(:params => params, 
      :filter => 'Helpdesk::Filters::ArchiveTicketFilter')
    
    respond_to do |format|
      format.html do
        @current_options = params
        @show_options = show_options 
      end
      format.json do
        unless @response_errors.nil?
          render :json => {:errors => @response_errors}.to_json
        else
          array = []
          @items.each { |tic| 
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
    @items = current_account.archive_tickets.permissible(current_user).filter(:params => params, 
      :filter => 'Helpdesk::Filters::ArchiveTicketFilter')
    
    respond_to do |format|
      format.js {}
    end
  end

  def show
    @to_emails = @ticket.to_emails
    @page_title = %([##{@ticket.display_id}] #{@ticket.subject})

    respond_to do |format|
      format.html  {
        @ticket_notes = @ticket_notes.reverse
        @ticket_notes_total = @ticket.conversation_count
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
    Resque.enqueue(Helpdesk::TicketsExport, params)
    flash[:notice] = t("export_data.ticket_export.info")
    redirect_to helpdesk_archive_tickets_path
  end

  def activities
    return activity_json if request.format == "application/json"
    if params[:since_id].present?
      activity_records = @item.activities.archive_tickets_activity_since(params[:since_id])
    elsif params[:before_id].present?
      activity_records = @item.activities.archive_tickets_activity_before(params[:before_id])
    else
      activity_records = @item.activities.newest_first.first(3)
    end
    
    @activities = stacked_activities(activity_records.reverse, true)
    
    # Omitting the Ticket Creation activity as in helpdesk/ticket_activities.rb
    @total_activities =  @item.activities.size - 1 

    if params[:since_id].present? or params[:before_id].present?
      render :partial => "helpdesk/archive_tickets/show/activity.html.erb", :collection => @activities
    else
      render :layout => false
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

  private
    def set_filter_options
      @filters_options = scoper_user_filters.map { |i| {:id => i[:id], :name => i[:name], :default => false, :user_id => i.accessible.user_id} }
    end

    def scoper_user_filters
      current_account.ticket_filters.my_ticket_filters(current_user)
    end

    def load_ticket
      @ticket = @item = current_account.archive_tickets.find_by_display_id(params[:id])
      @item || raise(ActiveRecord::RecordNotFound)
    end

    def load_sort_order
      params[:wf_order] = view_context.current_wf_order.eql?(:status) ? "created_at" : view_context.current_wf_order.to_s
      params[:wf_order_type] = view_context.current_wf_order_type.to_s
    end

    def verify_permission
      unless current_user && current_user.has_ticket_permission?(@item)
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
      @ticket_notes = @ticket.conversation(nil, default_notes_count, [:survey_remark, :user, :attachments, :schema_less_note, :cloud_files])
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
        params[:data_hash] = ActiveSupport::JSON.encode [{"operator"=>"is_in", 
                              "condition"=>"owner_id", "value"=> params[:company_id] }]
    end
  end

  def check_feature
    unless current_account.features?(:archive_tickets)
      redirect_to helpdesk_tickets_url
    end
  end

  def run_on_slave(&block)
    Sharding.run_on_slave(&block)
  end 
    
end
