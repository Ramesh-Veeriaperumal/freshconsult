module HelpdeskSystem

 def access_denied  
    store_location unless current_user
    respond_to do |format|
      format.html { 
        flash[:notice] = current_user ? I18n.t(:'flash.general.access_denied') : 
                                        I18n.t(:'flash.general.need_login')

        redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) unless request.headers['X-PJAX']
        render :text => "abort" if request.headers['X-PJAX']
      }
      format.json { 
        session.delete(:return_to) 
        render :json => current_user ? {:access_denied => true} : {:require_login => true}}
      format.js { 
        render :update do |page| 
          page.redirect_to :url => send(Helpdesk::ACCESS_DENIED_ROUTE)
        end
      }
    end
 end 

  def unprocessable_entity
    respond_to do |format|
      format.html {
        unless request.headers['X-PJAX']
          render :file => "#{Rails.root}/public/422.html", :status => :unprocessable_entity
        else
          render :text => "abort", :status => :unprocessable_entity
        end
      }
      format.json { 
        render :json => {:unprocessable_entity => true}}
      format.js { 
        render :update do |page| 
          page.redirect_to "/422.html"
        end
      }
    end
  end

 protected
  
  #Method to check permission for dropbox destroy. [todo attachments]
  def check_destroy_permission
    can_destroy = false
      
    @items.each do |dropbox|
      if ['Helpdesk::Ticket', 'Helpdesk::Note'].include? dropbox.droppable_type
        ticket = dropbox.droppable.respond_to?(:notable) ? dropbox.droppable.notable : dropbox.droppable
        can_destroy = true if privilege?(:manage_tickets) or (current_user && ticket.requester_id == current_user.id)
      elsif ['Solution::Article'].include?  dropbox.droppable_type
        can_destroy = true if privilege?(:publish_solution) or (current_user && dropbox.droppable.user_id == current_user.id)
      elsif ['Account'].include?  dropbox.droppable_type
        can_destroy = true if privilege?(:manage_account)
      elsif ['Post'].include?  dropbox.droppable_type
        can_destroy = true if privilege?(:edit_topic) or (current_user && dropbox.droppable.user_id == current_user.id)
      elsif ['User'].include?  dropbox.droppabe_type
        can_destroy = true if privilege?(:manage_users) or (current_user && dropbox.droppable.id == current_user.id)
      end
    end
    
    unless can_destroy
       flash[:notice] = t(:'flash.general.access_denied')
       redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) 
    end
  end
    
end
