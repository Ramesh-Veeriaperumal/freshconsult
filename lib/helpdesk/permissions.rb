module Helpdesk::Permissions

  def verify_ticket_permission(ticket)    
    verified = true
    unless ticket && current_user && current_user.has_ticket_permission?(ticket) && !ticket.trashed
      verified = false
      flash[:notice] = access_denied_message
      handle_responses(helpdesk_tickets_url)
    end
    verified
  end

  def verify_user_permission(item)
    user = current_user || User.current
    item_user = item && item.user
    verified = true
    unless item && user && item_user && (user.id == item_user.id)
      verified = false
      #Similar to access_denied except for format.js
      flash[:notice] = access_denied_message
      handle_responses
    end
    verified
  end

  private

  def access_denied_message
    t("flash.general.access_denied") 
  end

  def handle_responses(redirect_url = send(Helpdesk::ACCESS_DENIED_ROUTE)) 
    respond_to do |format|
      format.html {
        flash[:notice] = access_denied_message
        redirect_to redirect_url unless request.headers['X-PJAX']
        render :text => "abort" if request.headers['X-PJAX']
      }
      format.json { 
        render :json => current_user ? {:access_denied => true} : {:require_login => true}}
      format.js { 
        render :js => "window.location.href='"+ redirect_url +"'"
      }
      format.widget {
        render :text =>  access_denied_message
      }
    end
  end

end
