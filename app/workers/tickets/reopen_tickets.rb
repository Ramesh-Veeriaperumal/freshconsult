class Tickets::ReopenTickets < BaseWorker

  sidekiq_options :queue => :reopen_tickets, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    account = Account.current
    tickets = account.tickets.where(:display_id => args[:ticket_ids])
    tickets.find_each do |ticket|
      if ([Helpdesk::Ticketfields::TicketStatus::RESOLVED,
        Helpdesk::Ticketfields::TicketStatus::CLOSED].include?(ticket.status))
        ticket.misc_changes = {:assoc_parent_tkt_open => ["*"]}
        ticket.update_attributes(:status => Helpdesk::Ticketfields::TicketStatus::OPEN)
      end
    end
  rescue Exception => e
    puts e.inspect
    NewRelic::Agent.notice_error(e, {:description => "Error in tickets reopen ::
      #{args} :: #{account.id}"})
    raise e #to ensure it shows up in the failed jobs queue in sidekiq
  end
end
