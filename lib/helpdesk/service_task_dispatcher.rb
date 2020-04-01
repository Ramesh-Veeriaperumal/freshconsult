class Helpdesk::ServiceTaskDispatcher < Helpdesk::Dispatcher
  SERVICE_TASK_DISPATCHER_ERROR = ' SERVICE_TASK_DISPATCHER_EXECUTION_FAILED'.freeze

  def self.enqueue(ticket, user_id)
    args = { ticket_id: ticket.id, user_id: user_id, is_webhook: ticket.freshdesk_webhook? }
    job_id = Admin::ServiceTaskDispatcher::Worker.perform_async(args)
    Va::Logger::Automation.log("Triggering Service Task Dispatcher, job_id=#{job_id}", true)
  rescue StandardError => e
    Va::Logger::Automation.log_error(SERVICE_TASK_DISPATCHER_ERROR, e)
    NewRelic::Agent.notice_error(e)
    raise e
  end

  def rules
    @account.service_task_dispatcher_rules
  end

  def rule_type
    VAConfig::RULES_BY_ID[VAConfig::RULES[:service_task_dispatcher]]
  end

  def skip_rr?
    true
  end
end
