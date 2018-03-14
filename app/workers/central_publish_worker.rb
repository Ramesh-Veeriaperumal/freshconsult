module CentralPublishWorker
  class FreeTicketWorker < CentralPublisher::Worker
    sidekiq_options :queue => "free_ticket_central_publish", :retry => 5, :dead => true, :failures => :exhausted
  end

  class TrialTicketWorker < CentralPublisher::Worker
    sidekiq_options :queue => "trial_ticket_central_publish", :retry => 5, :dead => true, :failures => :exhausted
  end

  class ActiveTicketWorker < CentralPublisher::Worker
    sidekiq_options :queue => "active_ticket_central_publish", :retry => 5, :dead => true, :failures => :exhausted
  end

  class AccountDeletionWorker < CentralPublisher::Worker

    def perform(payload_type, args = {})
      @payload_type = payload_type
      @args = args.symbolize_keys
      connection = CentralPublisher.configuration.central_connection
      # Sample payload: 
      # {
      #   "account_id": 87,
      #   "payload_type": "account_destroy",
      #   "payload": {
      #     "model": "Account",
      #     "actor": {
      #       "type": "system"
      #     },
      #     "action": "destroy",
      #     "event_timestamp": "2018-02-01T11:25:38Z",
      #     "model_changes": {},
      #     "uuid": "a0c02e2e074211e89d53186590d131cf",
      #     "account_full_domain": "sample48.freshdesk-dev.com",
      #     "model_properties": {
      #       "id": 87,
      #       "name": "SAMPLE40",
      #       "full_domain": "sample48.freshdesk-dev.com"
      #     }
      #   }
      # }
      response = connection.post { |r| r.body = request_body.to_json }
      raise CentralPublishError, "Central returned #{response.status}" if response.status != 202
      Rails.logger.info("Central Publish Success: #{@args[:uuid]}, Response = #{response.body}")
    rescue => e
      log_publish_failure(response, e)
      raise e
    end

    private

      def request_body
        {
          account_id: @args[:model_properties]["id"],
          payload_type: @payload_type,
          payload: payload
        }
      end

      def payload
        model_data = {
          model: "Account",
          actor: actor,
          action: event_name,
          event_timestamp: event_timestamp.try(:utc).try(:iso8601),
          model_changes: {},
          uuid: @args[:uuid],
          account_full_domain: @args[:model_properties]["full_domain"]
        }
          
        model_data.merge!(model_properties)
      end
  
      def actor
        { type: 'system' }
      end
  end
end
