
class SlaOnStatusChange < BaseWorker

  sidekiq_options :queue => :sla_on_status_change, :retry => 0, :failures => :exhausted
  
  def perform(args)
    Thread.current[:sbrr_log] = [self.jid]
   	args.symbolize_keys!
   	@status = Account.current.ticket_statuses.find_by_id args[:status_id]
   	if args[:status_changed]
   	  @status.update_tickets_properties
   	else
   	  @status.update_tickets_sla
   	end
  ensure
    Thread.current[:sbrr_log] = nil
  end

end