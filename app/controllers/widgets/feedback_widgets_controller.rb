class Widgets::FeedbackWidgetsController < SupportController
  skip_before_filter :verify_authenticity_token
  include SupportTicketControllerMethods 

  def new
    @enable_pattern = true    

    @ticket_fields = current_portal.customer_editable_ticket_fields
    @ticket_fields_def_pos = ["default_requester", "default_subject", "default_description"]

    @js_options = {
      :formTitle => params[:formTitle] || t('feedbackwidget_defaulttitle')
    }
       
    # @ticket_fields_def_pos.reverse.each_with_index do |tf_field, new_pos|
    #   old_pos = @ticket_fields.map(&:field_type).index(tf_field)
    #   @ticket_fields.unshift(@ticket_fields.delete_at(old_pos)) if(old_pos != nil)
    # end
    set_portal_page :submit_ticket
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
end
