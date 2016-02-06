module Integrations
  class ApiWebhookRuleWorker < ::BaseWorker

    sidekiq_options :queue => :api_webhook_rule, :retry => 0, :backtrace => true, :failures => :exhausted

    def perform(args={})
      begin
        account = Account.current
        args = args.deep_symbolize_keys
        evaluate_on = account.send(args[:association].pluralize.to_sym).find args[:evaluate_on_id]
        account.api_webhooks_rules_from_cache.each do |vr|
          is_a_match = vr.event_matches? args[:current_events], evaluate_on
          vr.pass_through evaluate_on, nil, nil if is_a_match
        end
      rescue Exception => error
        Rails.logger.debug "Error in api_webhook_rule worker - #{error.inspect}"
        NewRelic::Agent.notice_error(error)
      end
    end

  end
end