class Support::TicketsController < ApplicationController
  
  #validates_captcha_of 'Helpdesk::Ticket', :only => [:create]
  include SupportTicketControllerMethods 
  before_filter { |c| c.requires_permission :portal_request }
  before_filter :only => [:new, :create] do |c| 
    c.check_portal_scope :anonymous_tickets
  end
  before_filter :require_user_login , :only =>[:index,:filter,:close_ticket]
  
  uses_tiny_mce :options => Helpdesk::TICKET_EDITOR
  
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
    render :index
  end
  
  def close_ticket
    @item = Helpdesk::Ticket.find_by_param(params[:id], current_account)
     status_id = Helpdesk::Ticket::STATUS_KEYS_BY_TOKEN[:closed]
     logger.debug "close the ticket...with status id  #{status_id}"
     res = Hash.new
     if @item.update_attribute(:status , status_id)
       res["success"] = true
       res["status"] = 'Closed'
       res["value"] = status_id
       res["message"]="Successfully updated"
       render :json => ActiveSupport::JSON.encode(res)
     else
       res["success"] = false
       res["message"]="closing the ticket failed"
       render :json => ActiveSupport::JSON.encode(res)
       
     end
  end
   
  protected 
    def redirect_url
      current_user ? support_ticket_url(@ticket) : root_path
    end
  
   def current_filter
      params[:id] || 'all'
    end
  
    def build_tickets
       @tickets = TicketsFilter.filter(current_filter.to_sym, current_user, current_user.tickets)
       @tickets = @tickets.paginate(:page => params[:page], :per_page => 10) 
       @tickets ||= []    
   end
   
   def require_user_login
     return redirect_to(send(Helpdesk::ACCESS_DENIED_ROUTE)) unless current_user
   end
  
   

end
