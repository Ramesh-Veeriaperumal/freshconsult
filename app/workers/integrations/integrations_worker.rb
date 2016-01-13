module Integrations
  class IntegrationsWorker < ::BaseWorker

    sidekiq_options :queue => :integrations, :retry => 0, :backtrace => true, :failures => :exhausted

    def perform(options = {})
      options = options.symbolize_keys
      begin
        obj = Integrations::IntegrationOperationsHandler.new
        if options[:operation_name].present?
          value = options[:operation_name]
          obj.send(value, options)
        end
      rescue Exception => error
        Rails.logger.debug "Integrations worker job failed - #{error}"
        NewRelic::Agent.notice_error(error)
      end

    end
  end
end

