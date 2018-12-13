module SearchService
  class ClicksLogger
    include Singleton

    LOGGER_PATH = Rails.root.join('log', 'search_clicks.log').freeze

    def log_info(uuid, log_data)
      output = []
      output << "s=#{log_data['xRequestId']}"
      output << "a=#{Account.current.id}"
      output << "u=#{User.current.id}"
      output << "h=#{log_data['totalResults']}"
      output << "p=#{log_data['pageNumber']}"
      output << "pos=#{log_data['itemPosition']}"
      output << "d_id=#{log_data['modelId']}"
      output << "d_type=#{log_data['model']}"
      output << "t=#{log_data['term']}"
      output << "l=#{log_data['spot']}"
      output << "e_s=#{log_data['emberGUID']}"
      log(uuid, output.join(', '))
    end

    private

      def timestamp
        Time.zone.now.utc.strftime('%Y-%m-%d %H:%M:%S.%L')
      end

      def log_device
        ::Logger.new(LOGGER_PATH)
      end

      def log(uuid, message, level = 'info')
        log_device.safe_send(level, "[#{uuid}] [#{timestamp}] #{message}")
      rescue Exception => e
        Rails.logger.error("Exception in ES Clicks Logger :: #{e.message}")
        NewRelic::Agent.notice_error(e)
      end
  end
end
