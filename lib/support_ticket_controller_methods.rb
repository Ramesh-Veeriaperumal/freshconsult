module SupportTicketControllerMethods

  include Helpdesk::TicketActions
  
  def show
    @ticket = Helpdesk::Ticket.find_by_param(params[:id], current_account)
    return if current_user && @ticket.requester_id == current_user.id
    return if permission?(:manage_tickets)
    return if current_user && current_user.client_manager?  &&@ticket.requester.customer == current_user.customer
    redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) 
  end

  def new
    @ticket = Helpdesk::Ticket.new 
    @ticket.email = current_user.email if current_user
  end
  
  def create
    puts "Create method in support controller methods"
    if create_the_ticket(feature?(:captcha))
      flash[:notice] = I18n.t(:'flash.portal.tickets.create.success')
      redirect_to redirect_url and return
    else
      logger.debug "Ticket Errors is #{@ticket.errors}"
      render :action => :new
    end
  end 
end
