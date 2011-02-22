module HelpdeskSystem
  def self.included(base)
    base.send :helper_method, :permission?
  end

  def requires_permission(p)
    unless permission?(p)
      store_location
      flash[:notice] = current_user ? "You don't have sufficient privileges to access this page" : 
                                      "You must be logged in to access this page"
      redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
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