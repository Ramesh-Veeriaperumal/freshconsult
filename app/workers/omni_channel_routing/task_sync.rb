module OmniChannelRouting
  class TaskSync < BaseWorker
    include ::OmniChannelRouting::Util

    sidekiq_options queue: :ocr_task_sync, retry: 5, backtrace: true, failures: :exhausted

    def perform(args)
      args.symbolize_keys!
      account = Account.current
      payload = { attributes: args[:attributes], changes: args[:changes] }
      Rails.logger.debug "***** OCR payload #{payload.inspect}"
      response = send_request(args[:id], payload)
      Rails.logger.info "Task changes sync successful. A=#{account.id} T=#{args[:id]} Response:: #{response}"
    rescue Exception => e
      Rails.logger.error "Error while syncing task changes #{e.message} :: #{e.backtrace[0..10].inspect}"
      NewRelic::Agent.notice_error(e, { account_id: account.id, args: args })
      raise e
    end

    private

      def send_request(ticket_id, payload)
        url = format(TICKET_UPDATE_PATH, ticket_id: ticket_id)
        # WIll remove this later
        # val = $redis_others.perform_redis_op("incr", "OCR_KEY")
        # url = url.sub("3001", "300#{val % 3 + 1}") if Account.current.launched?(:ocr_rr)
        RestClient::Request.execute(
          method: :put,
          url: url,
          payload: payload.to_json,
          headers: headers,
          timeout: 10,
          open_timeout: 10
        )
      end
  end
end
