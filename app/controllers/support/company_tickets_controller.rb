class Support::CompanyTicketsController < ApplicationController
  
  include SupportTicketControllerMethods 
  before_filter { |c| c.requires_permission :portal_request }
  before_filter :only => [:new, :create] do |c| 
    c.check_portal_scope :anonymous_tickets
  end
  
  before_filter :verify_permission
  
  def index    
    build_tickets
    respond_to do |format|
      format.html
      format.xml  { render :xml => @tickets.to_xml }
    end    
  end
  
  def filter   
    build_tickets
    render :index
  end
  
  def requester    
    @requested_by = params[:id]
    build_tickets
    render :index
  end
  
  protected
  
  def current_filter
    params[:id] || 'visible'
  end
  
  def build_tickets
     @tickets = TicketsFilter.filter(current_filter.to_sym , current_user , ticket_scope.tickets)
     @tickets ||= []    
  end
  
  def ticket_scope
    current_account.users.find_by_id(@requested_by) || current_user.customer
  end
  
  def verify_permission
    params.symbolize_keys!  
    return redirect_to(send(Helpdesk::ACCESS_DENIED_ROUTE)) unless current_user && current_user.client_manager?   
  end
  
end
