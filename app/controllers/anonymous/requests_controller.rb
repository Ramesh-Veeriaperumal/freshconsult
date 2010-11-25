class Anonymous::RequestsController < ApplicationController #by Shan temp need to revisit. Duplicated with support/ticketscontroller
  include SupportTicketControllerMethods
  
  #before_filter :captcha_check, :only => :create

  layout 'support/default'

  protected

    def redirect_url
      support_ticket_url(@ticket, :access_token => @ticket.access_token)
    end

#    def captcha_check
#      if !verify_recaptcha
#    end
end
