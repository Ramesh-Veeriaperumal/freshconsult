module HelpdeskSystem
  def self.included(base)
    base.send :helper_method, :permission?
  end

  def requires_permission(p)
    redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) unless permission?(p)
  end
  
  protected
  
    def permission?(p)
      # If no authorizations have been created, the system should
      # not have any restrictions.
      return true if Helpdesk::Authorization.count == 0

      if current_user
        auth = Helpdesk::Authorization.find_by_user_id(current_user.id) 
        role = auth ? auth.role : Helpdesk::ROLES[:customer]
      else
        role = Helpdesk::ROLES[:anonymous]
      end

      role[:permissions][p]
    end
    
end