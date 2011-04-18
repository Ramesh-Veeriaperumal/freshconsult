module SupportTicketControllerMethods

  include Helpdesk::TicketActions
  
  def show
    @ticket = Helpdesk::Ticket.find_by_param(params[:id], current_account)
    return if current_user && @ticket.requester_id == current_user.id
    return if permission?(:manage_tickets)
    redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) 
  end

  def new
    @ticket = Helpdesk::Ticket.new 
    set_customizer
    @ticket.email = current_user.email if current_user
  end
  
  def set_customizer
    @ticket.customizer ||= Helpdesk::FormCustomizer.first(:conditions =>{:account_id =>current_account.id})
  end

  def create
    if create_the_ticket(true)
      flash[:notice] = "Your ticket has been created and a copy has been sent to you via email."
      redirect_to redirect_url and return
    else
      set_customizer
      logger.debug "Ticket Errors is #{@ticket.errors}"
      render :action => :new
    end
  end 
end
