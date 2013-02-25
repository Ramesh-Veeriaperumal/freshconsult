class Widgets::FeedbackWidgetsController < SupportController
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

  def search_solutions
    render :partial => "/search/pagesearch", :locals => { :placeholder => '', :url => "/search/solutions?search_key=" }
  end

  def submit_feedback
    @ticket = Helpdesk::Ticket.new 
    @ticket.email = current_user.email if current_user
    render :partial => "feedbackwidget_form"
  end
end
