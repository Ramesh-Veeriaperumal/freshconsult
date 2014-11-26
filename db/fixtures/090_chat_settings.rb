account = Account.current

chat_setting = ChatSetting.seed(:account_id) do |c|
  c.account_id = account.id
  c.active = true
end

ChatWidget.seed(:account_id) do |c|
	c.name = account.name
  c.account_id = account.id
  c.show_on_portal = false
	c.portal_login_required = false
  c.active = false
  c.chat_setting_id = chat_setting.id
  c.main_widget = true
end