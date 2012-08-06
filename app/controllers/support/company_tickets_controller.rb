class Support::CompanyTicketsController < SupportController
  
  include SupportTicketControllerMethods 
  before_filter { |c| c.requires_permission :portal_request }
  before_filter :only => [:new, :create] do |c| 
    c.check_portal_scope :anonymous_tickets
  end
  
  before_filter :set_mobile, :only => [:index, :filter]

  before_filter :verify_permission
  
  def index    
    @page_title = t('helpdesk.tickets.views.all_tickets') + " inside " + current_user.customer.name
    build_tickets
    @ticket_filters = render_to_string :partial => "/support/shared/filters"
    @tickets_list = render_to_string :partial => "/support/shared/tickets"    
    respond_to do |format|
      format.html
      format.xml  { render :xml => @tickets.to_xml }
    end    
  end
  
  def filter   
    @page_title = TicketsFilter::CUSTOMER_SELECTOR_NAMES[current_filter.to_sym]
    build_tickets
    respond_to do |format|
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
      format.html {
        render :index
      }
    end
  end
  
  def requester    
    @requested_by = params[:id]
    @page_title = "Tickets by #{current_account.users.find_by_id(@requested_by).name}"
    build_tickets
    render :index
  end
  
  protected  
    def current_filter
      params[:id] || 'all'
    end
  
    def build_tickets
       @tickets = TicketsFilter.filter(current_filter.to_sym, current_user, ticket_scope.tickets)
       @tickets = @tickets.paginate(:page => params[:page], :per_page => 10) 
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
  
end
