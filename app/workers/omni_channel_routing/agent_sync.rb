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
      response = request_service(:freshdesk, :put, service_paths[:update_agent] % { user_id: user_id.to_s }, payload.to_json)
      Rails.logger.info "Agent availability sync to ocr Agent_id:::: #{user_id} :::: #{response}"    
    rescue Exception => e
      Rails.logger.error "Error while sync Agent availability changes #{e.message}"
      NewRelic::Agent.notice_error(e, {:args => args})
      raise e
    end
  end
end
