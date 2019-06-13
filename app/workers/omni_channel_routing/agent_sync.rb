module OmniChannelRouting
  class AgentSync < BaseWorker
    include ::OmniChannelRouting::Util

    sidekiq_options :queue => :ocr_agent_sync, :retry => 5, :failures => :exhausted

    def perform(args)
      args.symbolize_keys!
      account = Account.current
      user_id = args[:user_id]      
      availability = args[:availability]
      payload = { freshdesk_availability: availability }
      response = send_request(user_id, payload)
      Rails.logger.info "Agent availability sync to ocr Agent_id:::: #{user_id} :::: #{response}"    
    rescue Exception => e
      Rails.logger.error "Error while sync Agent availability changes #{e.message}"
      NewRelic::Agent.notice_error(e, {:args => args})
      raise e
    end

    private

      def send_request(user_id, payload)
        url = format(AGENT_UPDATE_PATH, user_id: user_id)
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
