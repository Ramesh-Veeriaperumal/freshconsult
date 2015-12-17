class Admin::DynamicNotificationTemplatesController < Admin::AdminController
  include LiquidSyntaxParser

  before_filter :load_item, :validate_liquid

	def update
    if @errors.present?
      flash_msg = @errors.join("<br>").html_safe
      render :json => { :success => false, :msg => flash_msg }
    else
  		if @dynamic_notification.update_attributes(params[:dynamic_notification_template])
    		flash[:notice] = t(:'flash.email_notifications.update.success')
    	else
     		flash[:notice] = t(:'flash.email_notifications.update.failure') 	
     	end	

      render :json => { :success => true, :url => redirect_url }
    end 
	end	

  private

  def load_item
    @dynamic_notification = (params[:id].blank?) ? current_account.dynamic_notification_templates.new : 
      current_account.dynamic_notification_templates.find_by_id(params[:id])
    redirect_to admin_email_notifications_path, :flash => { :notice => t('email_notifications.page_not_found') } if @dynamic_notification.nil?
  end

  def validate_liquid
    ["subject", "description"].each do |suffix|
      syntax_rescue(params[:dynamic_notification_template]["#{suffix}"])
    end
  end

  def redirect_url
    language = DynamicNotificationTemplate::LANGUAGE_MAP_KEY[params[:dynamic_notification_template][:language].to_i].to_s
    url_params = {:id => params[:dynamic_notification_template][:email_notification_id], :type => template_type}
    "#{admin_edit_notification_path(url_params)}##{language}"
  end

  def template_type
    notfn = @dynamic_notification.email_notification
    if notfn.reply_template?
      "reply_template"
    elsif notfn.cc_notification?
      "cc_notification"
    elsif @dynamic_notification.category == DynamicNotificationTemplate::CATEGORIES[:agent]
      "agent_template"
    else
      "requester_template"
    end
  end
end	
