class Widgets::FeedbackWidgetsController < ApplicationController
  skip_before_filter :check_privilege
  skip_before_filter :verify_authenticity_token
  include SupportTicketControllerMethods 
  
  def thanks
    
  end
  
  def create
    if create_the_ticket
     respond_to do |format|
        format.html { render :action => :thanks}
        format.xml  { head 200}
      end
    else
      render :action => :new
    end
    
  end
end
