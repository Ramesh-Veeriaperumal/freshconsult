module HelpdeskSystem

 def access_denied  
    store_location unless current_user
    Rails.logger.error "Access denied :: #{access_denied_message}" if Account.current && Account.current.launched?(:logout_logs)
    respond_to do |format|
      format.html { 
        flash[:notice] = access_denied_message

        redirect_to safe_send(Helpdesk::ACCESS_DENIED_ROUTE) unless request.headers['X-PJAX']
        render :text => "abort" if request.headers['X-PJAX']
      }
      format.any(:json,:nmobile) { 
        session.delete(:return_to) 
        render :json => current_user ? {:access_denied => true} : {:require_login => true}}
      format.js { 
        flash[:notice] = access_denied_message
        redirect_url = safe_send(Helpdesk::ACCESS_DENIED_ROUTE)
        render :js => "window.location.href='"+ redirect_url +"'"
      }
      format.widget {
        render :text =>  access_denied_message
      }
    end
 end 

 def check_account_activation 
      access_denied unless current_account.verified? 
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
    return if @item.nil? && @items.nil?
    process_denied unless @items.nil? ? @item.can_be_deleted_by_me? : @items.all? { |f| f.can_be_deleted_by_me? }
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
    redirect_to safe_send(Helpdesk::ACCESS_DENIED_ROUTE) 
  end

  def template_priv? item
    privilege?(:manage_ticket_templates) or item.visible_to_only_me?
  end
  
end
