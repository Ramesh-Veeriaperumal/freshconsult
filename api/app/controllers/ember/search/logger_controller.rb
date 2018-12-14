module Ember
  module Search
    class LoggerController < ApiApplicationController
      skip_before_filter :before_load_object, :load_object, :after_load_object

      def log_click
        SearchService::ClicksLogger.instance.log_info(request.env['action_dispatch.request_id'], params['data'])
      rescue Exception => e
        Rails.logger.error("Error in Search Logger controller :: #{e.message}")
        NewRelic::Agent.notice_error(e)
      ensure
        head 204
      end
    end
  end
end
