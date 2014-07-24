module ChatHelper

  def is_chat_plan?
    freshchat_plans = [ SubscriptionPlan::SUBSCRIPTION_PLANS[:garden], SubscriptionPlan::SUBSCRIPTION_PLANS[:estate],
                        SubscriptionPlan::SUBSCRIPTION_PLANS[:forest], SubscriptionPlan::SUBSCRIPTION_PLANS[:garden_classic],
                        SubscriptionPlan::SUBSCRIPTION_PLANS[:estate_classic], SubscriptionPlan::SUBSCRIPTION_PLANS[:premium] ]
    freshchat_plans.include?(current_account.subscription_plan.name)
  end

  def chat_agents_list
    Base64.strict_encode64(current_account.agents_from_cache.collect { |c| {:name=>c.user.name, :id=>c.user.id} }.to_json.html_safe )
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

  def prechat_form_input_value(value, name)
    value.blank? ?  name : value
  end

  def helpdesk_name_check(value,name)
      if value.include? "{{helpdesk_name}}"
        value.sub('{{helpdesk_name}}',name)
      else
        value
      end
  end

  def freshchat_setting
    chat_setting = current_account.chat_setting
    business_calendar = chat_setting.business_calendar.to_json({:only => [:time_zone, :business_time_data, :holiday_data]})
    preferences = chat_setting.preferences
    non_available_message = chat_setting.non_availability_message
    if preferences  
      window_color = preferences['window_color'].blank? ? t("freshchat.window_color") : preferences['window_color']
      window_position = preferences['window_position'].blank? ? t("freshchat.window_position") : preferences['window_position']
      window_offset = preferences['window_offset'].blank? ? t("freshchat.window_offset") : preferences['window_offset']
      text_place = preferences['text_place'].blank? ? t("freshchat.text_placeholder") : preferences['text_place']
      connecting_msg = preferences['connecting_msg'].blank? ? t("freshchat.connecting_msg") : preferences['connecting_msg']
      agent_joined_msg = preferences['agent_joined_msg'].blank? ? t("freshchat.agent_joined_msg") : helpdesk_name_check(preferences['agent_joined_msg'],current_account.helpdesk_name)
      agent_left_msg = preferences['agent_left_msg'].blank? ? t("freshchat.agent_left_msg") : helpdesk_name_check(preferences['agent_left_msg'],current_account.helpdesk_name)
      minimized_title = preferences['minimized_title'].blank? ? t("freshchat.minimized_title") : preferences['minimized_title'] 
      maximized_title = preferences['maximized_title'].blank? ? t("freshchat.maximized_title") : preferences['maximized_title']
      welcome_message = preferences['welcome_message'].blank? ? t("freshchat.welcome_message") : preferences['welcome_message']
      thank_message = preferences['thank_message'].blank? ? t("freshchat.thank_message") : preferences['thank_message']
      wait_message = preferences['wait_message'].blank? ? t("freshchat.wait_message") : preferences['wait_message']
    else
      window_color = "#777777"
      window_position = "Bottom Right"
      window_offset = 30
      text_place = t("freshchat.text_placeholder")
      connecting_msg = t("freshchat.connecting_msg")
      agent_joined_msg = t("freshchat.agent_joined_msg")
      agent_left_msg = t("freshchat.agent_left_msg")
      minimized_title = t("freshchat.minimized_title")
      maximized_title =t("freshchat.maximized_title")
      welcome_message = t("freshchat.welcome_message")
      thank_message = t("freshchat.thank_message")
      wait_message = t("freshchat.wait_message")
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
      :minimized_title => minimized_title,
      :maximized_title => maximized_title,
      :welcome_message => welcome_message,
      :thank_message => thank_message, 
      :wait_message => wait_message, 
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
      :agent_joined_msg => agent_joined_msg, 
      :agent_left_msg  => agent_left_msg, 
      :connecting_msg => connecting_msg,
      :non_availability_message => non_availability_message,
      :me => t("freshchat.me") ,
      :name_label =>  prechat_form_input_value(chat_setting.prechat_form_name, t("freshchat.name")),
      :mail_label => prechat_form_input_value(chat_setting.prechat_form_mail, t("freshchat.mail")),
      :phone_label => prechat_form_input_value(chat_setting.prechat_form_phoneno, t("freshchat.phone")),
      :text_place => text_place,
      :begin_chat => t("freshchat.begin_chat"), 
      :color => window_color,
      :offset =>  window_offset, 
      :position => window_position,
      :ticket_link_option => ticket_link_option, 
      :expiry =>  chat_trial_expiry,
      :custom_link_url => custom_link_url,
      :environment => Rails.env
    }
    return freshchat_setting.to_json.html_safe
  end

end