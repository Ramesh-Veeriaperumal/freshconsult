module CentralPublish
  class CRECentralWorker < BaseWorker
    include KafkaCollector::CollectorRestClient
    include CentralPublish::CRECentralUtil

    sidekiq_options queue: :cre_central_publish, retry: 0, dead: true, failures: :exhausted

    def perform(args, payload_type)
      args.symbolize_keys!
      payload = nil
      payload = construct_webhook_error_payload(args) if payload_type == CRE_PAYLOAD_TYPES[:webhook_error]
      response = post_to_central(payload)
      {
        status: response,
        data: payload
      }
    end

    def post_to_central(payload)
      msg_id = generate_msg_id(payload)
      post_to_collector(payload.to_json, msg_id, false)
    end
  end
end
