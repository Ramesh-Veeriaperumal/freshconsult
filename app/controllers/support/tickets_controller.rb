class Support::TicketsController < ApplicationController

  include SupportTicketControllerMethods 

  before_filter { |c| c.requires_permission :portal_request }

  def index
    return redirect_to(send(Helpdesk::ACCESS_DENIED_ROUTE)) unless current_user
    @tickets = Helpdesk::Ticket.find_all_by_requester_id(current_user.id)
    @tickets ||= []
  end

protected

  def redirect_url
    current_user ? support_ticket_url(@ticket) : root_path
  end

end
