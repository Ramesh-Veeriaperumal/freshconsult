account = Account.current

ticket = Helpdesk::Ticket.seed(:account_id, :subject) do |s|
  s.account_id = account.id
  s.subject = "This is a sample ticket"
  s.description_html = 'This is a sample ticket, feel free to delete it.'
  s.email = "rachel@freshdesk.com"
  s.status = Helpdesk::Ticketfields::TicketStatus::OPEN
  s.source = TicketConstants::SOURCE_KEYS_BY_TOKEN[:portal]
  s.priority = TicketConstants::PRIORITY_KEYS_BY_TOKEN[:low]
  s.ticket_type = "Question"
end

