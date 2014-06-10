account = Account.current

Survey.seed(:account_id) do |s|
  s.account_id = account.id
  s.link_text = 'Please tell us what you think of your support experience.'
  s.send_while = Survey::RESOLVED_NOTIFICATION
end