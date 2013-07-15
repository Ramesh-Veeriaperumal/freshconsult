module SupportTicketControllerMethods

  include Helpdesk::TicketActions
  
  def show
    @ticket = current_account.tickets.find_by_param(params[:id], current_account)    
    unless can_access_support_ticket?
      access_denied
    else
      respond_to do |format|
        format.html
      end
    end
  end

  def new    
    set_portal_page :submit_ticket
  end
  
  def create
    puts "Create method in support controller methods"
    if create_the_ticket(feature?(:captcha))
      flash.keep(:notice)
      flash[:notice] = I18n.t(:'flash.portal.tickets.create.success')
      redirect_to redirect_url
    else
      logger.debug "Ticket Errors is #{@ticket.errors}"
      set_portal_page :submit_ticket
      render :action => :new
    end
  end
  
  def can_access_support_ticket?
    @ticket && (privilege?(:manage_tickets)  ||  (current_user  &&  ((@ticket.requester_id == current_user.id) || 
                          ( privilege?(:client_manager) && @ticket.requester.customer == current_user.customer))))
  end
  
  def show_survey_form
    render :partial => "/support/shared/survey_form" if customer_survey_required?
  end

  def customer_survey_required?
    can_access_support_ticket? && current_account && current_account.features?(:survey_links) && @ticket.closed?
  end

  def check_email
    items = check_email_scoper.find(
              :all, 
              :conditions => ["email = ?", "#{params[:v]}"])
    respond_to do |format|
      format.json { render :json => { :user_exists => items.present? }  }
    end
  end  

   private
  
    def check_email_scoper
      current_account.all_users
    end

end
