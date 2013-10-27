account = Account.current

ticket = Helpdesk::Ticket.seed(:account_id, :subject) do |s|
  s.account_id = account.id
  s.subject = "This is a sample ticket"
  s.email = Helpdesk::EMAIL[:default_requester_email]
  s.status = Helpdesk::Ticketfields::TicketStatus::OPEN
  s.source = TicketConstants::SOURCE_KEYS_BY_TOKEN[:portal]
  s.priority = TicketConstants::PRIORITY_KEYS_BY_TOKEN[:low]
  s.ticket_type = "Question"
  s.cc_email = {:cc_emails => [], :fwd_emails => []}
end

Helpdesk::TicketBody.seed(:account_id, :ticket_id) do |s|
	s.ticket_id = ticket.id
	s.account_id = account.id
  s.description = 'This is a sample ticket, feel free to delete it.'
	s.description_html = '<div>This is a sample ticket, feel free to delete it.</div>'
end
