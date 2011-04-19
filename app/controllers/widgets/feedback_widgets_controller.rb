class Widgets::FeedbackWidgetsController < ApplicationController
  include SupportTicketControllerMethods 
  
  def thanks
    
  end
  
  def create
    if create_the_ticket
      flash[:notice] = "Your ticket has been created and a copy has been sent to you via email."
      render :action => :thanks
    else
      set_customizer
      logger.debug "Ticket Errors is #{@ticket.errors}"
      render :action => :new
    end
  end
end
