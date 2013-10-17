account = Account.current

ChatSetting.seed(:account_id) do |c|
  c.account_id = account.id
  c.minimized_title = I18n.t('freshchat.minimized_title')
  c.maximized_title = I18n.t('freshchat.maximized_title')
  c.welcome_message = I18n.t('freshchat.welcome_message')
  c.thank_message = I18n.t('freshchat.thank_message')
  c.wait_message = I18n.t('freshchat.wait_message')
  c.typing_message = I18n.t('freshchat.typing_message')
  c.prechat_form = 1
  c.prechat_message = I18n.t('freshchat.prechat_message')
  c.prechat_phone = 0
  c.prechat_mail = 0
  c.proactive_chat = 0
  c.proactive_time = 10
  

end