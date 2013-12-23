class Widgets::FeedbackWidgetsController < SupportController

  skip_before_filter :check_privilege
  skip_before_filter :verify_authenticity_token
  before_filter :build_item, :only => :new
  include SupportTicketControllerMethods 

  def new
    @widget_form = true

    @ticket_fields = current_portal.customer_editable_ticket_fields
    @ticket_fields_def_pos = ["default_requester", "default_subject", "default_description"]
  end
  
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

  private 

    def build_item
      @ticket = current_account.tickets.new
      @ticket.build_ticket_body
      @ticket.source = Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:feedback_widget]
    end

end
