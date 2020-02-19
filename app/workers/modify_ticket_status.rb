class ModifyTicketStatus < BaseWorker

  sidekiq_options :queue => :modify_ticket_status, :retry => 0, :failures => :exhausted

  include Helpdesk::BulkActionMethods
  include Helpdesk::Ticketfields::TicketStatus

  def perform(args)
    begin
      create_redis_key_on_job_start(args[:status_id])
      args.symbolize_keys!
      new_status_id = Helpdesk::Ticketfields::TicketStatus::OPEN
      ticket_statuses = account.ticket_statuses.where({:status_id => [args[:status_id], new_status_id]})
      new_ticket_status = ticket_statuses.to_a.find {|x| x.status_id == new_status_id}
      group_ids = Set.new

      account.tickets.where(:status => args[:status_id]).find_in_batches(:batch_size => 300) do |tickets|
        tickets.each do |ticket|
          ticket.status = new_status_id
          # Adding misc_changes to ticket for updating activities
          ticket.misc_changes = { :delete_status => [args[:status_name], new_status_id] }
          status_sla_toggled_to = TicketConstants::STATUS_SLA_TOGGLED_TO[new_ticket_status.stop_sla_timer]
          ticket.status_sla_toggled_to = status_sla_toggled_to if stop_sla_timer_changed?(ticket_statuses)
          ticket.skip_sbrr_assigner = ticket.bg_jobs_inline = true
          ticket.save!
          group_ids.add ticket.group_id
        end
      end
      Rails.logger.info("Status updated as OPEN for deleted ticket status")
      increment_redis_key_on_job_end(args[:status_id])
      destroy_ticket_status_on_all_jobs_completion(args[:status_id])
    rescue => e
      Rails.logger.info("Something went wrong in ModifyTicketStatus while updating status")
      NewRelic::Agent.notice_error(e, {:custom_params => {:args => args }})
      raise e
    ensure
      sbrr_assigner(group_ids, {:jid => self.jid}) 
    end
  end

  def stop_sla_timer_changed? ticket_statuses
    ticket_statuses.first.stop_sla_timer != ticket_statuses.last.stop_sla_timer
  end

  def account
    Account.current
  end

end
