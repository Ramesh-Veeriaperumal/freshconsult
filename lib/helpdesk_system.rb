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

    #Method to check permission for dropbox destroy. [todo attachments]
    def check_destroy_permission
      can_destroy = false
        
      @items.each do |dropbox|
        if ['Helpdesk::Ticket', 'Helpdesk::Note'].include? dropbox.droppable_type
          ticket = dropbox.droppable.respond_to?(:notable) ? dropbox.droppable.notable : dropbox.droppable
          can_destroy = true if permission?(:manage_tickets) or (current_user && ticket.requester_id == current_user.id)
        elsif ['Solution::Article'].include?  dropbox.droppable_type
          can_destroy = true if permission?(:manage_knowledgebase) or (current_user && dropbox.droppable.user_id == current_user.id)
        elsif ['Account'].include?  dropbox.droppable_type
          can_destroy = true if permission?(:manage_users)
        elsif ['Post'].include?  dropbox.droppable_type
          can_destroy = true if permission?(:manage_forums) or (current_user && dropbox.droppable.user_id == current_user.id)
        elsif ['User'].include?  dropbox.droppabe_type
          can_destroy = true if permission?(:manage_users) or (current_user && dropbox.droppable.id == current_user.id)
        end
      end
    
      unless  can_destroy
         flash[:notice] = t(:'flash.general.access_denied')
         redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) 
      end
      end
    
end