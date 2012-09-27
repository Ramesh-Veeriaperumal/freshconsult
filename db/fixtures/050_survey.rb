account = Account.current

Survey.seed(:account_id) do |s|
  s.account_id = account.id
  s.link_text = 'Please let us know your opinion on our support experience.'
  s.send_while = Survey::RESOLVED_NOTIFICATION
end