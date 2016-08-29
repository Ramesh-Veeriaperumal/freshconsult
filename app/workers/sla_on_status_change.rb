
class SlaOnStatusChange < BaseWorker

  sidekiq_options :queue => :sla_on_status_change, :retry => 0, :backtrace => true, :failures => :exhausted
  
  def perform(args)
   	args.symbolize_keys!
   	@status = Account.current.ticket_statuses.find_by_id args[:status_id]
   	if args[:status_changed]
   	  @status.update_tickets_sla_on_status_change
   	else
   	  @status.update_tickets_sla
   	end
  end

end