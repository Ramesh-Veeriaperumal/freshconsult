account = Account.current

ticket = Helpdesk::Ticket.seed(:account_id, :subject) do |s|
  s.account_id = account.id
  s.subject = "This is a sample ticket"
  s.description = 'This is a sample ticket, feel free to delete it.'
  s.email = "rachel@freshdesk.com"
  s.status = TicketConstants::STATUS_KEYS_BY_TOKEN[:open]
  s.source = TicketConstants::SOURCE_KEYS_BY_TOKEN[:portal]
  s.priority = TicketConstants::PRIORITY_KEYS_BY_TOKEN[:low]
  s.ticket_type = TicketConstants::TYPE_KEYS_BY_TOKEN[:how_to]
end

Helpdesk::Activity.seed(:account_id, :notable_id, :notable_type) do |s|
  s.account_id = account.id
  s.description = 'activities.tickets.new_ticket.long'
  s.notable_id = ticket.id
  s.notable_type = "Helpdesk::Ticket"
  s.user_id = ticket.requester_id
  s.short_descr = 'activities.tickets.new_ticket.short'
  s.activity_data = {}
end
