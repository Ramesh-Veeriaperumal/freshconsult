class ModifyTicketStatus < BaseWorker

  sidekiq_options :queue => :modify_ticket_status, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform(args)
    begin
      account = Account.current
      args.symbolize_keys!
      account.tickets.where(:status => args[:status_id]).find_in_batches(:batch_size => 300) do |tickets|
        tickets.each do |ticket|
         ticket.status = Helpdesk::Ticketfields::TicketStatus::OPEN
         # Adding misc_changes to ticket for updating activities
         ticket.misc_changes = { :delete_status => [args[:status_name], Helpdesk::Ticketfields::TicketStatus::OPEN] }
         ticket.save!
        end
      end
      Rails.logger.info("Status updated as OPEN for deleted ticket status")
    rescue => e
      Rails.logger.info("Something went wrong in ModifyTicketStatus while updating status")
      NewRelic::Agent.notice_error(e, {:custom_params => {:args => args }})
      raise e
    end
  end
end