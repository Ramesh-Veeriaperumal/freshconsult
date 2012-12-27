module HelpdeskSystem

 def access_denied  
    respond_to do |format|
      format.html { 
        flash[:notice] = current_user ? I18n.t(:'flash.general.access_denied') : 
                                        I18n.t(:'flash.general.need_login')

        redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) 
      }
      format.json { render :json => { :access_denied => true } }
      format.js { 
        render :update do |page| 
          page.redirect_to :url => send(Helpdesk::ACCESS_DENIED_ROUTE)
        end
      }
    end
 end 
    
end
