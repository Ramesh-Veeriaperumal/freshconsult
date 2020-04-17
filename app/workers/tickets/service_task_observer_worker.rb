module Tickets
  class ServiceTaskObserverWorker < ObserverWorker
    sidekiq_options queue: :service_task_observer, retry: 0, failures: :exhausted
    OBSERVER_ERROR = 'SERVICE_TASK_OBSERVER_EXECUTION_FAILED'.freeze

    def rule_type
      VAConfig::RULES_BY_ID[VAConfig::RULES[:service_task_observer]]
    end

    def rules
      Account.current.service_task_observer_rules_from_cache
    end

    def evaluate_rr?
      false
    end

    def evaluate_sla?
      false
    end

    def enable_ocr_sync?
      false
    end

    def original_ticket_data(evaluate_on, original_attributes)
      evaluate_on
    end

    def update_original_ticket_with_changes(evaluate_on, original_ticket)
      evaluate_on
    end
  end
end
