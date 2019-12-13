class Admin::EmailNotificationsController < Admin::AdminController 
  include LiquidSyntaxParser
  include Spam::SpamAction
  include Utils::RequesterPrivilege
  
  before_filter :load_item, :except => :index
  before_filter :validate_liquid, :detect_spam_action, :only => :update
  before_filter :validate_params, :only => :edit
  before_filter :email_notifications_allowed? , :only => [:update]
  before_filter :access_denied, if: :check_privileges, except: :index

  NOTIFICATION_LIST = ['@agent_notifications', '@user_notifications', '@reply_templates', '@forward_templates', '@cc_notifications'].freeze

  def index
    fetch_notifications
    respond_to do |format|
      format.html
      format.any(:json) { render request.format.to_sym => scoper.map{|notify| {:id=>notify.id,:requester_notification => notify.requester_notification,:agent_notification => notify.agent_notification}}}
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
    if @email_notification.safe_send(url_check).nil?
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
    @scoper ||= current_account.sla_management_enabled? ? current_account.email_notifications : current_account.email_notifications.non_sla_notifications
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

  def init_notifications
    NOTIFICATION_LIST.each do |x|
      self.instance_variable_set(x, [])
    end
  end

  def fetch_notifications
    init_notifications
    other_notifications_access = has_other_notifications_privilege?
    requester_access = has_requester_privilege?
    scoper.each do |e_notification|
      @agent_notifications << e_notification if e_notification.visible_to_agent? && other_notifications_access && !system_notify_private_template?(e_notification)
      @user_notifications << e_notification if e_notification.visible_to_requester? && requester_access
      @reply_templates << e_notification if e_notification.reply_template? && other_notifications_access
      @forward_templates << e_notification if e_notification.forward_template? && other_notifications_access
      @cc_notifications << e_notification if e_notification.cc_notification? && other_notifications_access
    end
  end

  def system_notify_private_template?(notification)
    return false if notification.notification_type != EmailNotification::AUTOMATED_PRIVATE_NOTES

    !Account.current.automated_private_notes_notification_enabled?
  end

  def check_privileges
    return if has_all_privileges? || @email_notification.nil?

    !(check_requester_privilege || check_other_notification_privilege)
  end

  def check_requester_privilege
    has_requester_privilege? && accessing_requester_info?
  end
end
