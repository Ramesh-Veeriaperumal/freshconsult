class Admin::EmailNotificationsController < Admin::AdminController 
  include LiquidSyntaxParser

  before_filter :load_item, :except => :index
  before_filter :validate_liquid, :only => :update
  
  def index
    e_notifications = current_account.email_notifications 

    @agent_notifications = e_notifications.select { |n| n.visible_to_agent? }
    
    @user_notifications = e_notifications.select { |n| n.visible_to_requester? }
    
    @reply_templates = e_notifications.select { |n| n.reply_template? }

    @cc_notifications = e_notifications.select { |n| n.cc_notification? }
  end
  
  def update
    if @errors.present?
      flash_msg = @errors.join("<br>")
      render :json => { :success => false, :msg => flash_msg }
    else
      if params[:outdated]
        if params[:requester]
          params[:email_notification][:outdated_requester_content] = true
          DynamicNotificationTemplate.where(:email_notification_id => @email_notification.id, 
            :category =>DynamicNotificationTemplate::CATEGORIES[:requester]).update_all({:outdated => true})            
        elsif params[:agent]
          params[:email_notification][:outdated_agent_content] = true
          DynamicNotificationTemplate.where(:email_notification_id => @email_notification.id, 
            :category =>DynamicNotificationTemplate::CATEGORIES[:agent]).update_all({:outdated => true})
        end   
      end
      if @email_notification.update_attributes(params[:email_notification])
        flash[:notice] = t(:'flash.email_notifications.update.success')
      else
        flash[:notice] = t(:'flash.email_notifications.update.failure')
      end
      render :json => { :success => true }
    end
  end

  def edit  
    @email_notification = current_account.email_notifications.find(params[:id])
    notification_type = @email_notification.notification_type
    @supported_languages = current_account.account_additional_settings.supported_languages
    @default_language = current_account.language 
    @type = params[:type]
    url_check = @email_notification.fetch_template || params[:type]
    if @email_notification.send(url_check).nil?
      flash[:error] = t(:'flash.email_notifications.update.does_not_exist')
      redirect_to admin_email_notifications_path
    end
  end   

  def update_agents 
    notification_agents = @email_notification.email_notification_agents
    notification_agents.each do |agent|
      agent.destroy
    end
    agents_data = ActiveSupport::JSON.decode(params[:email_notification_agents][:notifyagents_data])
    agents_data[@email_notification.id.to_s].each do |user_id|
      n_agent = current_account.users.technicians.find(user_id).email_notification_agents.build()
      n_agent.email_notification = @email_notification
      n_agent.account = current_account
      n_agent.save  
    end
    redirect_to :back
  end

  private

  def load_item
    @email_notification = current_account.email_notifications.find_by_id(params[:id])
    redirect_to admin_email_notifications_path, :flash => { :notice => t('email_notifications.page_not_found') } if @email_notification.nil?
  end

  def validate_liquid
    email_notfn = params[:email_notification]
    user = email_notfn.keys[0].include?("requester") ? "requester" : "agent"
    ["subject_template", "template"].each do |suffix|
      syntax_rescue(email_notfn["#{user}_#{suffix}"])
    end
  end
end
