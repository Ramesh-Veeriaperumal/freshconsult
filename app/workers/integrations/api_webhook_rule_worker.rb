module Integrations
  class ApiWebhookRuleWorker < ::BaseWorker

    sidekiq_options :queue => :api_webhook_rule, :retry => 0, :failures => :exhausted

    def perform(args={})
      begin
        account = Account.current
        args = args.deep_symbolize_keys
        association = args[:association].pluralize.to_sym
        evaluate_on = account.safe_send(association).find args[:evaluate_on_id]
        account.api_webhooks_rules_from_cache.each do |vr|
          begin
            Va::Logger::Automation.set_thread_variables(account.id, args[:evaluate_on_id], nil, vr.id) if association == :tickets
            is_a_match = vr.event_matches? args[:current_events], evaluate_on
            vr.pass_through evaluate_on, nil, nil if is_a_match
          rescue StandardError => error
            Rails.logger.debug "Error in api_webhook_rule worker - #{error.inspect}"
            NewRelic::Agent.notice_error(error)
          ensure
            Va::Logger::Automation.unset_thread_variables if association == :tickets
          end
        end
      end
    end
  end
end
