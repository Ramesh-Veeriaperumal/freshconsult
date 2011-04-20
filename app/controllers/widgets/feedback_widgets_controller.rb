class Widgets::FeedbackWidgetsController < ApplicationController
  include SupportTicketControllerMethods 
  
  def thanks
    
  end
  
  def create
    if create_the_ticket
      render :action => :thanks
    else
      set_customizer
      render :action => :new
    end
  end
end
