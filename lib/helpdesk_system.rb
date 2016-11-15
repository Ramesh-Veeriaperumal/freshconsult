module HelpdeskSystem

 def access_denied  
    store_location unless current_user
    Rails.logger.error "Access denied :: #{access_denied_message}" if Account.current.launched?(:logout_logs)
    respond_to do |format|
      format.html { 
        flash[:notice] = access_denied_message

        redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) unless request.headers['X-PJAX']
        render :text => "abort" if request.headers['X-PJAX']
      }
      format.any(:json,:nmobile) { 
        session.delete(:return_to) 
        render :json => current_user ? {:access_denied => true} : {:require_login => true}}
      format.js { 
        flash[:notice] = access_denied_message
        redirect_url = send(Helpdesk::ACCESS_DENIED_ROUTE)
        render :js => "window.location.href='"+ redirect_url +"'"
      }
      format.widget {
        render :text =>  access_denied_message
      }
    end
 end 

 def password_expired?
  current_user_session && current_user_session.stale_record && current_user_session.stale_record.password_expired
 end

 def access_denied_message
   current_user ? I18n.t(:'flash.general.access_denied') : 
        password_expired? ? I18n.t(:'flash.general.password_expired') : I18n.t(:'flash.general.need_login')
 end

  def unprocessable_entity
    respond_to do |format|
      format.html {
        unless request.headers['X-PJAX']
          render :file => "#{Rails.root}/public/422.html", :status => :unprocessable_entity, :layout => false
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
  
  #Method to check permission for normal attachments & cloud_files destroy.
  def check_destroy_permission
    can_destroy = false
    model_name  = define_model

    @items.each do |file|
      file_type       = file.send("#{model_name}_type")
      file_attachable = file.send(model_name)

      if ['Helpdesk::Ticket', 'Helpdesk::Note'].include? file_type
        ticket = file_attachable.respond_to?(:notable) ? file_attachable.notable : file_attachable
        can_destroy = true if privilege?(:manage_tickets) or (current_user && ticket.requester_id == current_user.id)
      elsif ['Solution::Article', 'Solution::Draft'].include? file_type
        can_destroy = true if privilege?(:publish_solution) or (current_user && file_attachable.user_id == current_user.id)
      elsif ['Account'].include? file_type
        can_destroy = true if privilege?(:manage_account)          
      elsif ['Post'].include? file_type
        can_destroy = true if privilege?(:edit_topic) or (current_user && file_attachable.user_id == current_user.id)
      elsif ['User'].include? file_type
        can_destroy = true if privilege?(:manage_users) or (current_user && file_attachable.id == current_user.id)
      elsif ['Helpdesk::TicketTemplate'].include? file_type
        can_destroy = true if template_priv? file_attachable
      elsif ['UserDraft'].include? attachment.attachable_type
        can_destroy = true if (current_user && file_attachable.id == current_user.id)
      end
      process_denied unless can_destroy
    end
  end

  def define_model
    if controller_name.eql?("attachments")
      "attachable"
    elsif controller_name.eql?("cloud_files")
      "droppable"
    else
      process_denied
    end
  end

  def process_denied
    flash[:notice] = t(:'flash.general.access_denied')
    redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) 
  end

  def template_priv? item
    privilege?(:manage_ticket_templates) or item.visible_to_only_me?
  end
  
end
