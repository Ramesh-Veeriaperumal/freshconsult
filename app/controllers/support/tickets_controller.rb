class Support::TicketsController < ApplicationController

  include SupportTicketControllerMethods

  layout 'support/default'

  before_filter { |c| c.requires_permission :portal_request }

  def index
    return redirect_to(send(Helpdesk::ACCESS_DENIED_ROUTE)) unless current_user
    @tickets = Helpdesk::Ticket.find_all_by_requester_id(current_user.id)
    @tickets ||= []
  end

protected

  def redirect_url
    support_ticket_url(@ticket, :access_token => @ticket.access_token)
  end

end
