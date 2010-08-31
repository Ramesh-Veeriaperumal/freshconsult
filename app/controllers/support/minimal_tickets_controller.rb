class Support::MinimalTicketsController < ApplicationController

  include SupportTicketControllerMethods

  layout 'support/minimal'

  before_filter { |c| c.requires_permission :portal_request }

protected

  def redirect_url
    support_minimal_ticket_url(@ticket)
  end

end
