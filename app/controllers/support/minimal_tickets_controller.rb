class Support::MinimalTicketsController < ApplicationController

  include SupportTicketControllerMethods

  layout 'support/minimal'

  skip_before_filter :check_privilege

protected

  def redirect_url
    support_minimal_ticket_url(@ticket)
  end

end
