module Tickets
  class ObserverWorker < BaseWorker

    sidekiq_options :queue => :ticket_observer, :retry => 0, :backtrace => true, :failures => :exhausted
    SYSTEM_DOER_ID = -1
    OBSERVER_ERROR = 'OBSERVER_EXECUTION_FAILED'.freeze

    def perform args 
      begin
        args.symbolize_keys!
        account, ticket_id, doer_id, system_event = Account.current, args[:ticket_id], args[:doer_id], args[:system_event]
        current_events = args[:current_events].symbolize_keys
        sla_args = args[:sla_args].try(:symbolize_keys)
        Va::Logger::Automation.set_thread_variables(account.id, ticket_id, doer_id)

        evaluate_on = account.tickets.find_by_id ticket_id
        evaluate_on.attributes = args[:attributes]
        doer = account.users.find_by_id doer_id unless system_event
        Va::Logger::Automation.log("system_event=#{system_event}, user_nil=#{doer.nil?}") if (system_event || doer.nil?)
        if evaluate_on.present? and (doer.present? || system_event)
          start_time = Time.now.utc
          rule_type = VAConfig::RULES_BY_ID[VAConfig::RULES[:observer]]
          Thread.current[:observer_doer_id] = doer_id || SYSTEM_DOER_ID
          aggregated_response_time = 0
          observer_rules = account.observer_rules_from_cache
          observer_rules.each do |vr|
            Va::Logger::Automation.set_rule_id(vr.id)
            ticket = nil
            time = Benchmark.realtime {
              ticket = vr.check_events doer, evaluate_on, current_events
            }
            Va::Logger::Automation.log_execution_and_time(time, (ticket.present? ? 1 : 0), rule_type)
            aggregated_response_time += vr.response_time[:matches] || 0
          end
          end_time = Time.now.utc
          total_time = end_time - start_time
          Va::Logger::Automation.unset_rule_id
          Va::Logger::Automation.log_execution_and_time(total_time, observer_rules.size, rule_type, start_time, end_time)
          ticket_changes = evaluate_on.merge_changes(current_events, 
                            evaluate_on.changes) if current_events.present?
          evaluate_on.round_robin_on_ticket_update(ticket_changes) if evaluate_on.rr_allowed_on_update?
          ticket_changes = evaluate_on.merge_changes(ticket_changes, evaluate_on.changes.slice(:responder_id)) 
          evaluate_on.update_old_group_capping(ticket_changes)
          if sla_args && sla_args[:sla_on_background] && evaluate_on.is_in_same_sla_state?(sla_args[:sla_state_attributes])
            evaluate_on.update_sla = true
            evaluate_on.sla_calculation_time = sla_args[:sla_calculation_time]
          end
          evaluate_on.save!
          evaluate_on.va_rules_after_save_actions.each do |action|
            klass = action[:klass].constantize
            klass.safe_send(action[:method], action[:args])
          end
        else
          Va::Logger::Automation.log "Skipping observer worker, ticket present?=#{evaluate_on.present?}, user present?=#{(doer.present? || system_event)}"
        end
      rescue => e
        Va::Logger::Automation.log_error(OBSERVER_ERROR, e, args)
        NewRelic::Agent.notice_error(e, {:custom_params => {:args => args }})
        raise e
      ensure
        Va::Logger::Automation.log "********* END OF OBSERVER *********"
        Va::Logger::Automation.unset_thread_variables
        if Account.current.skill_based_round_robin_enabled?
          if args[:enqueued_class] == 'Helpdesk::Ticket'
            #merges the diff between previous save transaction & observer save transaction
            previous_changes = args[:model_changes]
            if evaluate_on.errors.any?
              evaluate_on.model_changes = previous_changes
            else
              evaluate_on.model_changes = evaluate_on.merge_changes previous_changes, evaluate_on.model_changes
            end
            evaluate_on.sbrr_state_attributes = args[:sbrr_state_attributes]
            evaluate_on.enqueue_skill_based_round_robin if evaluate_on.should_enqueue_sbrr_job? && !evaluate_on.skip_sbrr
          else
            if evaluate_on.should_enqueue_sbrr_job? && !evaluate_on.skip_sbrr && !evaluate_on.errors.any?
              evaluate_on.enqueue_skill_based_round_robin
            end
          end
        end
        Thread.current[:observer_doer_id] = nil
        return {:sbrr_exec => evaluate_on.sbrr_exec_obj}
      end
    end
  end
end
