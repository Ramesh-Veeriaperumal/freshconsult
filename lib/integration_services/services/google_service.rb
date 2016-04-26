module IntegrationServices::Services
  class GoogleService < IntegrationServices::Service

    def receive_list_holidays
      begin
        handle_success({ :holidays => business_calendar_resource.holidays })
      rescue => e
        handle_error(e)
      end
    end

    private

      def business_calendar_resource
        @business_cal_resource ||= IntegrationServices::Services::Google::BusinessCalendarResource.new(self)
      end

      def handle_success hash_data
        hash_data[:error] = false
        hash_data
      end

      def handle_error e
        @logger.debug("Google Service error #{e.message}")
        NewRelic::Agent.notice_error(e)
        {:error => true, :error_message => e.message}
      end

  end
end
