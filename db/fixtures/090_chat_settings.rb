account = Account.current

ChatSetting.seed(:account_id) do |c|
  c.account_id = account.id
  c.preferences = HashWithIndifferentAccess.new({:window_color => "#777777",
                                                 :window_position => "Bottom Right",
                                                 :window_offset => 30,
                                                 :minimized_title => I18n.t('freshchat.minimized_title'),
                                                 :maximized_title => I18n.t('freshchat.maximized_title'),
                                                 :welcome_message => I18n.t('freshchat.welcome_message'),
                                                 :thank_message => I18n.t('freshchat.thank_message'),
                                                 :wait_message => I18n.t('freshchat.wait_message'),
                                                 :text_place => I18n.t("freshchat.text_placeholder"),
                                                 :connecting_msg => I18n.t("freshchat.connecting_msg"),
                                                 :agent_joined_msg => I18n.t("freshchat.agent_joined_msg"),
                                                 :agent_left_msg => I18n.t("freshchat.agent_left_msg")})
  c.prechat_form = 1
  c.prechat_message = I18n.t('freshchat.prechat_message')
  c.prechat_phone = 0
  c.prechat_mail = 0
  c.proactive_chat = 0
  c.proactive_time = 15
  
  c.show_on_portal = 1
  c.portal_login_required = 0

end