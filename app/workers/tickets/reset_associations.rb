class Tickets::ResetAssociations < BaseWorker

  sidekiq_options :queue => :reset_associations, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform(args)
  	args.symbolize_keys!
    tickets = Account.current.tickets.where(:id => args[:ticket_ids])
    tickets.find_each do |ticket|
      ticket.reset_associations
      ticket.update_attributes(:association_type => nil) if ticket.tracker_ticket? and args[:link_feature_disable]
    end
  end
end
