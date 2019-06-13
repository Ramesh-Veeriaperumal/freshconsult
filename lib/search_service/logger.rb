module SearchService
  class Logger
    attr_accessor :log_uuid, :log_data

    MULTIQUERY = '/multi_query'

    def initialize(uuid, log_data)
      @log_uuid = uuid || UUIDTools::UUID.timestamp_create.hexdigest
      @log_data = log_data
    end

    def log_info(request, response, account_id, additional_info)
      endpoint = request.url
      request_method = request.original_options[:method]
      request_payload =  (log_request_payload? ? request.original_options[:body] : nil)

      response_payload = (log_response_payload? ? response.body : nil)

      client_time = (response.total_time * 1000)
      starttransfer_time = (response.starttransfer_time * 1000)
      appconnect_time = (response.appconnect_time * 1000)
      pretransfer_time = (response.pretransfer_time * 1000)
      connect_time = (response.connect_time * 1000)
      namelookup_time = (response.namelookup_time * 1000)
      redirect_time = (response.redirect_time * 1000)

      output = []
      output << "account_id=#{account_id}"
      output << "request_method=#{request_method}"
      output << "endpoint=#{endpoint}"

      output << "response_code=#{response.code}"
      output << "hits=#{response.total_entries}"
      output << "client_time=#{client_time}"
      output << "starttransfer_time=#{starttransfer_time}"
      output << "appconnect_time=#{appconnect_time}"
      output << "pretransfer_time=#{pretransfer_time}"
      output << "connect_time=#{connect_time}"
      output << "namelookup_time=#{namelookup_time}"
      output << "redirect_time=#{redirect_time}"

      additional_info.each { |k, v| output << "#{k}=#{v}" }
      # when fuzzy search is launched
      if Account.current.launched?(:fuzzy_search) && endpoint.ends_with?(MULTIQUERY)
        parsed_response = JSON.parse(response.body)
        contexts = parsed_response['results'].keys
        totals = contexts.map { |c| parsed_response['results'][c]['total'] }
        contexts.zip(totals).each { |context, total| output << "context: #{context}, total: #{total}" }
      end

      output << "request_payload=#{request_payload}" if request_payload
      output << "response_payload=#{response_payload}" if response_payload
      output << "response_error=#{response.error}" if response.error
      log(output.join(', '))
    end

    private

      def timestamp
        Time.zone.now.utc.strftime('%Y-%m-%d %H:%M:%S.%L')
      end

      def log_path
        @@log_path ||= "#{Rails.root}/log/search_service_requests.log"
      end

      def log_device
        @@logger ||= ::Logger.new(log_path)
      end

      def log(message, level = 'info')
        log_device.safe_send(level, "[#{@log_uuid}] [#{timestamp}] #{message}")
      rescue Exception => e
        Rails.logger.error("[#{@log_uuid}] Exception in ES Logger :: #{e.message}")
        NewRelic::Agent.notice_error(e)
      end

      def log_payload?
        Account.current.try(:launched?, :es_payload_log) || (@log_data == Search::Utils::SEARCH_LOGGING[:all])
      end

      def log_request_payload?
        log_payload? # || (@log_data == Search::Utils::SEARCH_LOGGING[:request])
      end

      def log_response_payload?
        log_payload? # || (@log_data == Search::Utils::SEARCH_LOGGING[:response])
      end
  end
end
