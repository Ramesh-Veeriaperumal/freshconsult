module Middleware::Sidekiq::PublishToCentralUtil
  include KafkaCollector::CollectorRestClient

  PAYLOAD_TYPE = {
      job_enqueued: 'job_enqueued',
      job_picked_up: 'job_picked_up'
  }.freeze
  SIDEKIQ_LOGS_TO_CENTRAL_QUEUES = ['tickets_export_queue'].freeze

  def publish_data_to_central(msg, type)
    begin
      event_payload = construct_central_payload(msg, type)
      post_event_to_central(event_payload)
    rescue Exception => e
      Rails.logger.info("Error in publishing sidekiq job data to central #{e}")
    end
  end

  def construct_central_payload(job_data, type)
    payload = {
      payload_type: type,
      account_id: Account.current.id.to_s,
      payload:  {
          worker_name: job_data['class'],
          queue_name: job_data['original_queue'],
          job_id: job_data['jid']
      },
      pod: PodConfig['CURRENT_POD'],
      region: PodConfig['CURRENT_REGION']
    }
    case type
      when PAYLOAD_TYPE[:job_enqueued]
        payload[:payload][:enqueued_at] = Time.now.utc.iso8601
      when PAYLOAD_TYPE[:job_picked_up]
        payload[:payload][:enqueued_at] = job_data['enqueued_at']
        payload[:payload][:picked_up_at] = Time.now.utc.iso8601
    end
    payload
  end

  def post_event_to_central(event_payload)
    payload_for_msg_id = {
      payload_type: event_payload[:payload_type],
      job_id: event_payload[:payload][:job_id]
    }
    msg_id = Digest::MD5.hexdigest(payload_for_msg_id.to_s)
    response = post_to_collector(event_payload.to_json, msg_id, false)
    return {status: response, data: event_payload}
  end

  def publish_to_central?(queue_name)
    SIDEKIQ_LOGS_TO_CENTRAL_QUEUES.include?(queue_name) && Account.current.sidekiq_logs_to_central_enabled?
  end
end

