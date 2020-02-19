
class SlaOnStatusChange < BaseWorker

  sidekiq_options :queue => :sla_on_status_change, :retry => 0, :failures => :exhausted

  include Helpdesk::Ticketfields::TicketStatus

  def perform(args)
    args.symbolize_keys!
    # This job will trigger for both Sla timer stop and status deletion. We have to keep
    # track of the job start, end only when the job runs for status deletion
    create_redis_key_on_job_start(args[:status_id]) unless args[:status_changed]
    Thread.current[:sbrr_log] = [self.jid]
    @status = Account.current.ticket_statuses.find_by_status_id args[:status_id]
    if args[:status_changed]
      @status.update_tickets_properties
    else
      @status.update_tickets_sla
      increment_redis_key_on_job_end(@status.status_id)
      destroy_ticket_status_on_all_jobs_completion(@status.status_id)
    end
  ensure
    Thread.current[:sbrr_log] = nil
  end

end
