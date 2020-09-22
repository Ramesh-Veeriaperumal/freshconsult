module Tickets
  class ObserverWorker < BaseWorker
    include AutomationRuleHelper

    sidekiq_options :queue => :ticket_observer, :retry => 0, :failures => :exhausted
    SYSTEM_DOER_ID = -1
    OBSERVER_ERROR = 'OBSERVER_EXECUTION_FAILED'.freeze

    def perform args 
      begin
        args.symbolize_keys!
        account, ticket_id, doer_id, system_event = Account.current, args[:ticket_id], args[:doer_id], args[:system_event]
        current_events = args[:current_events].symbolize_keys
        original_attributes = args[:original_attributes].symbolize_keys if args[:original_attributes].present?
        sla_args = args[:sla_args].try(:symbolize_keys)
        Va::Logger::Automation.set_thread_variables(account.id, ticket_id, doer_id)

        evaluate_on = account.tickets.find_by_id ticket_id
        if evaluate_on.present? && Account.current.ticket_observer_race_condition_fix_enabled?
          schema_less_ticket = evaluate_on.schema_less_ticket
        end
        evaluate_on.thank_you_note_id = args[:note_id]
        evaluate_on.current_note_id = args[:note_id] if account.next_response_sla_enabled? && evaluate_sla?
        evaluate_on.attributes = args[:attributes]
        doer = account.users.find_by_id doer_id unless system_event

        Va::Logger::Automation.log("system_event=#{system_event}, user_nil=#{doer.nil?}", true) if system_event || doer.nil?
        if account.advanced_ticket_scopes_enabled? && doer && doer.only_read_ticket_permission?(evaluate_on)
          Va::Logger::Automation.log("skipping automation rule :: doer is a contribution agent user_id = #{doer.id}, ticket_id = #{ticket_id} ")
          return
        end
        if evaluate_on.present? and (doer.present? || system_event)
          start_time = Time.now.utc
          Thread.current[:observer_doer_id] = doer_id || SYSTEM_DOER_ID
          aggregated_response_time = 0
          rule_ids_with_exec_count = {}
          evaluate_on.prime_ticket_args = args
          original_ticket = original_ticket_data(evaluate_on, original_attributes)
          rules.each do |vr|
            begin
              Va::Logger::Automation.set_rule_id(vr.id, account.id, ticket_id, doer_id)
              ticket = nil
              time = Benchmark.realtime {
                ticket = account.automation_revamp_enabled? ?
                          vr.check_rule_events(doer, evaluate_on, current_events, original_ticket) :
                          vr.check_events(doer, evaluate_on, current_events)
              }
              original_ticket = update_original_ticket_with_changes evaluate_on, original_ticket
              rule_ids_with_exec_count[vr.id] = 1 if ticket.present?
              Va::Logger::Automation.log_execution_and_time(time, (ticket.present? ? 1 : 0), rule_type)
              aggregated_response_time += vr.response_time[:matches] || 0
            ensure
              Thread.current[:thank_you_note] = nil
            end
          end          
          update_ticket_execute_count(rule_ids_with_exec_count) if rule_ids_with_exec_count.present?
          end_time = Time.now.utc
          total_time = end_time - start_time
          Va::Logger::Automation.unset_rule_id
          Va::Logger::Automation.log_execution_and_time(total_time, rules.size, rule_type, start_time, end_time)
          ticket_changes = evaluate_on.merge_changes(current_events, 
                            evaluate_on.changes) if current_events.present?
          evaluate_on.round_robin_on_ticket_update(ticket_changes) if evaluate_on.rr_allowed_on_update? && evaluate_rr?
          ticket_changes = evaluate_on.merge_changes(ticket_changes, evaluate_on.changes.slice(:responder_id)) 
          evaluate_on.update_old_group_capping(ticket_changes) if evaluate_rr?
          if evaluate_sla? && sla_args && sla_args[:sla_on_background] && evaluate_on.is_in_same_sla_state?(sla_args[:sla_state_attributes])
            evaluate_on.update_sla = true
            evaluate_on.sla_calculation_time = sla_args[:sla_calculation_time]
          end
          evaluate_on.skip_ocr_sync = true
          skip_ocr_sync_on_retry = false
          schema_less_ticket.retrigger_observer = evaluate_on.changes.empty? ? false : true if Account.current.ticket_observer_race_condition_fix_enabled?
          evaluate_on.save!
          evaluate_on.va_rules_after_save_actions.each do |action|
            klass = action[:klass].constantize
            klass.safe_send(action[:method], action[:args])
          end
        else
          Va::Logger::Automation.log("Skipping observer worker, ticket present?=#{evaluate_on.present?}, user present?=#{(doer.present? || system_event)}", true)
        end
      rescue LockVersion::Utility::TicketParallelUpdateException => e
        Va::Logger::Automation.log(e.message, true)
        skip_ocr_sync_on_retry = true
        Tickets::RetryObserverWorker.perform_async(args) if Account.current.ticket_observer_race_condition_fix_enabled?
      rescue => e
        Va::Logger::Automation.log_error(OBSERVER_ERROR, err, args)
        NewRelic::Agent.notice_error(e, {:custom_params => {:args => args }})
        raise e
      ensure
        Va::Logger::Automation.unset_thread_variables
        if evaluate_rr? && Account.current.skill_based_round_robin_enabled?
          if evaluate_on.present? && args[:enqueued_class] == 'Helpdesk::Ticket'
            #merges the diff between previous save transaction & observer save transaction
            previous_changes = args[:model_changes]
            if evaluate_on.errors.any?
              evaluate_on.model_changes = previous_changes
            else
              evaluate_on.model_changes = evaluate_on.merge_changes previous_changes, evaluate_on.model_changes
            end
            evaluate_on.sbrr_state_attributes = args[:sbrr_state_attributes]
            evaluate_on.enqueue_skill_based_round_robin if evaluate_on.should_enqueue_sbrr_job? && !evaluate_on.skip_sbrr
          elsif evaluate_rr? && evaluate_on.should_enqueue_sbrr_job? && !evaluate_on.skip_sbrr && !evaluate_on.errors.any?
              evaluate_on.enqueue_skill_based_round_robin
          end
        end

        Thread.current[:observer_doer_id] = nil

        # Need to refactor this
        if enable_ocr_sync? && Account.current.omni_channel_routing_enabled? && !skip_ocr_sync_on_retry
          evaluate_on.skip_ocr_sync = false
          if evaluate_on.present? && args[:enqueued_class] == 'Helpdesk::Ticket'
            previous_changes = args[:model_changes]
            if evaluate_on.errors.any?
              evaluate_on.model_changes = previous_changes
            else
              evaluate_on.model_changes = evaluate_on.merge_changes previous_changes, evaluate_on.model_changes
            end
            evaluate_on.sync_task_changes_to_ocr if evaluate_on.allow_ocr_sync?
          elsif evaluate_rr? && enable_ocr_sync? && evaluate_on.allow_ocr_sync? && !evaluate_on.skip_sbrr && !evaluate_on.errors.any?
              evaluate_on.sync_task_changes_to_ocr
          end
        end
        return evaluate_rr? ? { sbrr_exec: evaluate_on.try(:sbrr_exec_obj) } : { sbrr_exec: nil }
      end
    end

    # Adding these methods since service_task_observer_worker.rb inherits this class
    def rule_type
      VAConfig::RULES_BY_ID[VAConfig::RULES[:observer]]
    end

    def rules
      Account.current.observer_rules_from_cache
    end

    def evaluate_rr?
      true
    end

    def evaluate_sla?
      true
    end

    def enable_ocr_sync?
      true
    end

    def original_ticket_data(evaluate_on, original_attributes)
      Account.current.observer_race_condition_fix_enabled? ? evaluate_on.duplicate(original_attributes) : evaluate_on
    end

    def update_original_ticket_with_changes(evaluate_on, original_ticket)
      if Account.current.observer_race_condition_fix_enabled?
        changed_attributes = evaluate_on.changes.each_with_object({}) do |(field, changes), hash|
          hash[field] = changes[1]
        end
        original_ticket.duplicate(changed_attributes)
      else
        original_ticket
      end
    end
  end
end
