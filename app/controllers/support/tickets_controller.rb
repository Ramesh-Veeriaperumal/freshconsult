class Support::TicketsController < ApplicationController
  
  #validates_captcha_of 'Helpdesk::Ticket', :only => [:create]
   
  include SupportTicketControllerMethods 
  
 

  before_filter { |c| c.requires_permission :portal_request }
  
  

  def index
    return redirect_to(send(Helpdesk::ACCESS_DENIED_ROUTE)) unless current_user
    @tickets = Helpdesk::Ticket.find_all_by_requester_id(current_user.id)
    @tickets ||= []
    
    respond_to do |format|
      format.html
      format.xml  { render :xml => @tickets.to_xml }
    end
    
  end
  
  def close_ticket 
    
    @item = Helpdesk::Ticket.find_by_param(params[:id], current_account)
     status_id = Helpdesk::Ticket::STATUS_KEYS_BY_TOKEN[:closed]
     logger.debug "close the ticket...with status id  #{status_id}"
     res = Hash.new
     if @item.update_attribute(:status , status_id)
       res["success"] = true
       res["status"] = 'Closed'
       res["value"] = status_id
       res["message"]="Successfully updated"
       render :json => ActiveSupport::JSON.encode(res)
     else
       res["success"] = false
       res["message"]="closing the ticket failed"
       render :json => ActiveSupport::JSON.encode(res)
       
     end
  end

protected

  def redirect_url
    current_user ? support_ticket_url(@ticket) : root_path
  end

end
