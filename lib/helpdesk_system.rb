module HelpdeskSystem
  def self.included(base)
    base.send :helper_method, :permission?
  end

  def requires_permission(p)
    unless permission?(p)
      store_location
      access_denied
    end
  end

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

  protected
  
    def permission?(p)
      # If no authorizations have been created, the system should
      # not have any restrictions.
      #return true if Helpdesk::Authorization.count == 0

#      if current_user
#        auth = Helpdesk::Authorization.find_by_user_id(current_user.id) 
#        role = auth ? auth.role : Helpdesk::ROLES[:customer]
#      else
#        role = Helpdesk::ROLES[:anonymous]
#      end

      role = current_user ? current_user.role : Helpdesk::ROLES[:anonymous]
      role[:permissions][p]
    end
    
end