account = Account.first

FlexifieldDef.seed(:account_id, :module) do |s|
  s.account_id = account.id
  s.module = "Ticket"
  s.name = "Ticket_#{account.id}"
end

Helpdesk::FormCustomizer.seed(:account_id) do |s|
  s.account_id = account.id
  s.name = "Ticket_#{account.id}"
  s.json_data = Helpdesk::FormCustomizer::DEFAULT_FIELDS_JSON
  s.requester_view = Helpdesk::FormCustomizer::DEFAULT_REQUESTER_FIELDS_JSON
end
