module Helpdesk::Permissible

  def verify_ticket_permission(ticket)    
    verified = true
    has_permission = current_user.access_all_agent_groups ? current_user.has_read_ticket_permission?(ticket) : current_user.has_ticket_permission?(ticket) if current_user
    unless ticket && current_user && has_permission && !ticket.trashed
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
    current_user ? t("flash.general.access_denied") : t("flash.general.need_login")
  end

  def handle_responses(redirect_url = safe_send(Helpdesk::ACCESS_DENIED_ROUTE)) 
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
