class Support::CompanyTicketsController < ApplicationController
  
  include SupportTicketControllerMethods
  include Support::CompanyTicketsHelper
  include ExportCsvUtil

  before_filter { |c| c.requires_permission :portal_request }
  before_filter :only => [:new, :create] do |c| 
    c.check_portal_scope :anonymous_tickets
  end
  
  before_filter :set_mobile, :only => [:index, :filter]

  before_filter :verify_permission
  before_filter :set_date_filter ,    :only => [:export_csv]
  before_filter :set_selected_tab
  
  def index    
    @page_title = t('helpdesk.tickets.views.all_tickets')
    build_tickets
    respond_to do |format|
      format.html
      format.xml  { render :xml => @tickets.to_xml }
    end    
  end
  
  def filter
    @page_title = TicketsFilter::CUSTOMER_SELECTOR_NAMES[current_filter.to_sym]
    build_tickets
    respond_to do |format|
      format.html {
        if params[:partial].blank?
          render :index
        else
          render :partial => "/support/shared/ticket_list"
        end
      }
      format.mobile {
        unless @response_errors.nil?
          render :json => {:errors => @response_errors}.to_json
        else
          json = "["; sep=""
          @tickets.each { |tic| 
            #Removing the root node, so that it conforms to JSON REST API standards
            # 19..-2 will remove "{helpdesk_ticket:" and the last "}"
            json << sep + tic.to_json({}, false)[19..-2]; sep=","
          }
          render :json => json + "]"
        end
      }
    end
  end
  
  def requester    
    @requested_by = params[:id]
    @page_title = "Tickets by #{current_account.users.find_by_id(@requested_by).name}"
    build_tickets
    if params[:partial].blank?
      render :index
    else
      render :partial => "/support/shared/ticket_list"
    end
  end
  
  def configure_export
    render :partial => "helpdesk/tickets/configure_export", :locals => {:csv_headers => export_fields(true)}
  end
  
  def export_csv
    params[:wf_per_page] = "100000"
    params[:page] = "1"
    csv_hash = params[:export_fields]
    unless params[:a].blank?
      if params[:a] == "requester"
        @requested_by = params[:i]
      else
        params[:id] = params[:i]
      end
    end 
    items = build_tickets
    export_data items, csv_hash, true
  end
 
   protected  
  
    def build_tickets
      date_added_ticket_scope = (params[:start_date].blank? or params[:end_date].blank?) ? ticket_scope.tickets : ticket_scope.tickets.created_at_inside(params[:start_date], params[:end_date])
       @tickets = TicketsFilter.filter(current_filter.to_sym, current_user, date_added_ticket_scope)
       @tickets = @tickets.paginate(:page => params[:page], :per_page => params[:wf_per_page] || 10, :order=> "#{current_wf_order} #{current_wf_order_type}") 
       @tickets ||= []    
    end
  
    def ticket_scope
      current_account.users.find_by_id(@requested_by) || current_user.customer
    end
  
    def verify_permission
      params.symbolize_keys!      
      unless current_user && current_user.client_manager?
        flash[:notice] = t("flash.general.access_denied")
        #redirect_to Helpdesk::ACCESS_DENIED_ROUTE 
        redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) 
      end
    end
  private
    def set_selected_tab
      @selected_tab = :"company_tickets"
    end
  
end
