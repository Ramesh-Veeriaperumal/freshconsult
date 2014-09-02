module ChatHelper

  def ticket_link_options
    return [  [  "...",  -1],
              [  I18n.t('freshchat.feedback_widget'),  0],
              [  I18n.t('freshchat.new_ticket_page'),  1],
              [  I18n.t('freshchat.custom_link'),      2] ]
  end

  def chat_feature_enabled?
    feature?(:chat) && current_account.chat_setting && current_account.chat_setting[:active]
  end

  def chat_active?
    chat_feature_enabled? && !current_account.subscription.suspended?
  end

  def portal_chat_enabled?
    chat_setting = current_account.chat_setting
    if chat_active? && chat_setting.show_on_portal 
      if logged_in?
        return current_user.customer?
      else
        return !chat_setting.portal_login_required
      end
    else
      return false
    end
  end

  def multiple_business_hours?
    feature?(:multiple_business_hours) && 
      current_account.business_calendar.count > 1
  end

  def default_business_hour
    current_account.business_calendar.default.first.id
  end

  def chat_trial_expiry
    subscription = current_account.subscription 
    subscription.trial? ? subscription.next_renewal_at.to_i * 1000 : 0
  end

  def encoded_freshchat_setting
    return Base64.strict_encode64(freshchat_setting)
  end

  def freshchat_setting
    chat_setting = current_account.chat_setting
    freshchat_setting = {
      :fc_id => chat_setting ? chat_setting.display_id : nil,
      :active => chat_setting ? chat_setting.active : false,
      :show_on_portal => chat_setting ? chat_setting.show_on_portal : 1,
      :portal_login_required => chat_setting ? chat_setting.portal_login_required : 0,
      :show => ChatSetting::CHAT_CONSTANTS_BY_KEY[:SHOW],
      :required => ChatSetting::CHAT_CONSTANTS_BY_KEY[:REQUIRED],
      :helpdeskname => current_account.helpdesk_name,
      :name_label =>  t("freshchat.name"),
      :mail_label => t("freshchat.mail"),
      :phone_label => t("freshchat.phone"),
      :textfield_label => t("freshchat.textfield"),
      :dropdown_label => t("freshchat.dropdown"),
      :weburl => current_account.full_domain,
      :nodeurl => ChatConfig["communication_url"][Rails.env],
      :debug => ChatConfig["chat_debug"][Rails.env],
      :me => t("freshchat.me"),
      :expiry =>  chat_trial_expiry,
      :environment => Rails.env,
      :default_window_offset => 30,
      :default_maximized_title => t("freshchat.maximized_title"),
      :default_minimized_title => t("freshchat.minimized_title"),
      :default_text_place => t("freshchat.text_placeholder"),
      :default_connecting_msg => t("freshchat.connecting_msg"),
      :default_welcome_message => t("freshchat.welcome_message"),
      :default_wait_message => t("freshchat.wait_message"),
      :default_agent_joined_msg => t("freshchat.agent_joined_msg"),
      :default_agent_left_msg => t("freshchat.agent_left_msg"),
      :default_thank_message => t("freshchat.thank_message"),
      :default_non_availability_message => t("freshchat.non_availability_message")
    }
    return freshchat_setting.to_json.html_safe
  end

end