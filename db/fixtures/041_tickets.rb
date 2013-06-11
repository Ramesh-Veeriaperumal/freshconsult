account = Account.current

ticket = Helpdesk::Ticket.seed(:account_id, :subject) do |s|
  s.account_id = account.id
  s.subject = "This is a sample ticket"
  s.email = "rachel@freshdesk.com"
  s.status = Helpdesk::Ticketfields::TicketStatus::OPEN
  s.source = TicketConstants::SOURCE_KEYS_BY_TOKEN[:portal]
  s.priority = TicketConstants::PRIORITY_KEYS_BY_TOKEN[:low]
  s.ticket_type = "Question"
end

Helpdesk::TicketBody.seed(:account_id, :ticket_id) do |s|
	s.ticket_id = ticket.id
	s.account_id = account.id
	s.description_html = '<div>This is a sample ticket, feel free to delete it.</div>'
end
