class Tickets::ResetAssociations < BaseWorker

  sidekiq_options :queue => :reset_associations, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform(args)
  	args.symbolize_keys!
    account = Account.current
    tickets = account.tickets.where(:display_id => args[:ticket_ids])
    tickets.find_each do |ticket|
      ticket.reset_associations
      ticket.update_attributes(:association_type => nil) if ticket.tracker_ticket? and args[:link_feature_disable]
    end
  rescue Exception => e
    puts e.inspect
    NewRelic::Agent.notice_error(e, {:description => "Error in resetting associated tickets ::
      #{args} :: #{account.id}"})
    raise e #to ensure it shows up in the failed jobs queue in sidekiq
  end
end