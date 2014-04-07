module ChatHelper

  def chat_agents_list
    Base64.strict_encode64(current_account.agents_from_cache.collect { |c| {:name=>c.user.name, :id=>c.user.id, :email=>c.user.email} }.to_json.html_safe )
  end

  def ticket_link_options
    return [  [  I18n.t('freshchat.feedback_widget'),  0],
              [  I18n.t('freshchat.new_ticket_page'),  1],
              [  I18n.t('freshchat.custom_link'),      2] ]
  end

  def chat_feature_enabled?
    feature?(:chat) && feature?(:chat_enable)
  end

  def chat_active?
    chat_feature_enabled? && !current_account.subscription.suspended? && current_account.chat_setting
  end

  def portal_chat_enabled?
    chat_setting = current_account.chat_setting
    chat_active? && chat_setting.show_on_portal && (!chat_setting.portal_login_required || logged_in?)
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
    business_calendar = chat_setting.business_calendar.to_json({:only => [:time_zone, :business_time_data, :holiday_data]})
    preferences = chat_setting.preferences
    non_available_message = chat_setting.non_availability_message
    if preferences
      window_color = preferences['window_color']
      window_position = preferences['window_position']
      window_offset = preferences['window_offset']
    else
      window_color = "#777777"
      window_position = "Bottom Right"
      window_offset = 30
    end
    unless non_available_message.blank?
      non_availability_message = non_available_message['text']
      ticket_link_option = non_available_message['ticket_link_option']
      custom_link_url = non_available_message['custom_link_url']
    else
      non_availability_message = t("freshchat.non_availability_message")
      ticket_link_option = 0
      custom_link_url = ""
    end
    freshchat_setting = {
      :fc_id => chat_setting.display_id, 
      :fc_se => chat_setting.visitor_session,
      :minimized_title => chat_setting.minimized_title.blank? ? t("freshchat.minimized_title") : chat_setting.minimized_title, 
      :maximized_title => chat_setting.maximized_title.blank? ? t("freshchat.maximized_title") : chat_setting.maximized_title,
      :welcome_message => chat_setting.welcome_message.blank? ? t("freshchat.welcome_message") : chat_setting.welcome_message,
      :thank_message => chat_setting.thank_message.blank? ? t("freshchat.thank_message") : chat_setting.thank_message, 
      :wait_message => chat_setting.wait_message.blank? ? t("freshchat.wait_message") : chat_setting.wait_message, 
      :typing_message => chat_setting.typing_message.blank? ? t("freshchat.typing_message") : chat_setting.typing_message,
      :prechat_message => chat_setting.prechat_message.blank? ? t("freshchat.prechat_message") : chat_setting.prechat_message, 
      :prechat_form => chat_setting.prechat_form,
      :prechat_mail => chat_setting.prechat_mail, 
      :prechat_phone => chat_setting.prechat_phone,  
      :proactive_chat => chat_setting.proactive_chat, 
      :proactive_time => chat_setting.proactive_time, 
      :business_calendar => business_calendar,
      :show_on_portal => chat_setting.show_on_portal, 
      :portal_login_required => chat_setting.portal_login_required,
      :weburl => current_account.full_domain, 
      :nodeurl => ChatConfig["communication_url"][Rails.env],
      :debug => ChatConfig["chat_debug"][Rails.env], 
      :agent_joined_msg => t("freshchat.agent_joined_msg") ,
      :agent_left_msg  => t("freshchat.agent_left_msg"), 
      :connecting_msg => t("freshchat.connecting_msg") ,
      :non_availability_message => non_availability_message,
      :me => t("freshchat.me") ,
      :name_place =>  t("freshchat.name"), 
      :mail_place => t("freshchat.mail") ,
      :phone_place => t("freshchat.phone"), 
      :text_place => t("freshchat.text_placeholder") ,
      :begin_chat => t("freshchat.begin_chat"), 
      :color => window_color,
      :offset =>  window_offset, 
      :position => window_position,
      :ticket_link_option => ticket_link_option, 
      :expiry =>  chat_trial_expiry,
      :custom_link_url => custom_link_url
    }
    return freshchat_setting.to_json.html_safe
  end

end