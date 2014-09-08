account = Account.current

ChatSetting.seed(:account_id) do |c|
  c.account_id = account.id

  c.active = false
  c.show_on_portal = 0
  c.portal_login_required = 0

end