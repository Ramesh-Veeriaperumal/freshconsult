module Tickets
  class ObserverWorker < BaseWorker

    sidekiq_options :queue => :ticket_observer, :retry => 0, :backtrace => true, :failures => :exhausted
    SYSTEM_DOER_ID = -1

    def perform args 
      begin
        args.symbolize_keys!
        account, ticket_id, doer_id, system_event = Account.current, args[:ticket_id], args[:doer_id], args[:system_event]
        current_events = args[:current_events].symbolize_keys

        evaluate_on = account.tickets.find_by_id ticket_id
        evaluate_on.attributes = args[:attributes]
        doer = account.users.find_by_id doer_id unless system_event

        if evaluate_on.present? and (doer.present? || system_event)
          Thread.current[:observer_doer_id] = doer_id || SYSTEM_DOER_ID
          aggregated_response_time = 0
          account.observer_rules_from_cache.each do |vr|
            vr.check_events doer, evaluate_on, current_events
            aggregated_response_time += vr.response_time[:matches] || 0
          end
          Rails.logger.debug "Response time :: #{aggregated_response_time}"
          ticket_changes = evaluate_on.merge_changes(current_events, 
                            evaluate_on.changes) if current_events.present?
          evaluate_on.round_robin_on_ticket_update(ticket_changes) if evaluate_on.rr_allowed_on_update?
          evaluate_on.update_old_group_capping(ticket_changes)
          evaluate_on.save!
          evaluate_on.va_rules_after_save_actions.each do |action|
            klass = action[:klass].constantize
            klass.send(action[:method], action[:args])
          end
        else
          puts "Skipping observer worker for : Account id:: #{Account.current.id}, Ticket id:: #{args[:ticket_id]}, User id:: #{args[:doer_id]}"            
        end
      rescue => e
        puts "Something is wrong Observer : Account id:: #{Account.current.id}, Ticket id:: #{args[:ticket_id]}, #{e.message}"
        NewRelic::Agent.notice_error(e, {:custom_params => {:args => args }})
        raise e
      ensure
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
