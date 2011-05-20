class Widgets::FeedbackWidgetsController < ApplicationController
  skip_before_filter :verify_authenticity_token
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
