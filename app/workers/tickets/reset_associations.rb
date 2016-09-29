class Tickets::ResetAssociations < BaseWorker

  sidekiq_options :queue => :reset_associations, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform(ticket_ids)
    tickets = Account.current.tickets.where(:id => ticket_ids)
    tickets.find_each do |ticket|
      ticket.reset_associations
    end
  end
end
