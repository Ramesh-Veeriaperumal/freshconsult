module Integrations
  class InstalledAppBusinessRuleWorker < ::BaseWorker

    sidekiq_options :queue => :installed_app_business_rule , :retry => 0, :backtrace => true, :failures => :exhausted

    def perform(args={})
      begin
        account = Account.current
        args = args.deep_symbolize_keys
        events = [args[:current_event].to_sym]
        evaluate_on = account.send(args[:association].pluralize.to_sym).find args[:evaluate_on_id]
        account.installed_app_business_rules_from_cache.each do |vr|
          vr.pass_through evaluate_on, events
        end
      rescue Exception => error
        Rails.logger.debug "Error in installed_app_business_rule worker - #{error.inspect}"
        NewRelic::Agent.notice_error(error)
      end
    end

  end
end