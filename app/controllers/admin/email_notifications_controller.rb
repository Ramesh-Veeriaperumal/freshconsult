class Admin::EmailNotificationsController < Admin::AdminController 
  include LiquidSyntaxParser
  include Spam::SpamAction
  
  before_filter :load_item, :except => :index
  before_filter :validate_liquid, :detect_spam_action, :only => :update
  before_filter :validate_params, :only => :edit
  before_filter :email_notifications_allowed? , :only => [:update]

  def index
    e_notifications = scoper

    @agent_notifications = e_notifications.select { |n| n.visible_to_agent? }
    
    @user_notifications = e_notifications.select { |n| n.visible_to_requester? }
    
    @reply_templates = e_notifications.select { |n| n.reply_template? }

    @forward_templates = e_notifications.select { |n| n.forward_template? }

    @cc_notifications = e_notifications.select { |n| n.cc_notification? }

    respond_to do |format|
      format.html
      format.any(:json) { render request.format.to_sym => e_notifications.map{|notify| {:id=>notify.id,:requester_notification => notify.requester_notification,:agent_notification => notify.agent_notification}}}
    end
  end
  
  def update
    if @errors.present?
      flash_msg = @errors.uniq.join("<br>")
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
        template_spam_check # we should handle this at model level in future
        flash[:notice] = t(:'flash.email_notifications.update.success')
      else
        flash[:notice] = t(:'flash.email_notifications.update.failure')
      end
      render :json => { :success => true }
    end
  end

  def edit  
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

  def email_notifications_allowed?
    check_account_activation
  end
  
  def scoper
    current_account.sla_management_enabled? ? current_account.email_notifications : current_account.email_notifications.non_sla_notifications
  end

  def load_item
    @email_notification = scoper.find_by_id(params[:id])
    redirect_to admin_email_notifications_path, :flash => { :notice => t('email_notifications.page_not_found') } if @email_notification.nil?
  end

  def validate_liquid
    email_notfn = params[:email_notification]
    user = email_notfn.keys[0].include?("requester") ? "requester" : "agent"
    ["subject_template", "template"].each do |suffix|
      syntax_rescue(email_notfn["#{user}_#{suffix}"])
    end
  end
    
  def extract_subject_and_message
    email_notfn = params[:email_notification]
    user = email_notfn.keys[0].include?("requester") ? "requester" : "agent"
    return email_notfn["#{user}_subject_template"], email_notfn["#{user}_template"]
  end

  def validate_params
    if ['agent_template','requester_template', 'cc_notification', 'reply_template','forward_template'].exclude? params[:type] #temp fix, if templates are added move to a constant
      redirect_to admin_email_notifications_path, :flash => { :error => t('email_notifications.page_not_found') }
    end
  end
end
