class Ryuken::EmailRateLimitingWorker
  include Shoryuken::Worker
  include EmailRateLimitHelper

  shoryuken_options queue: SQS[:email_rate_limiting_queue], auto_delete: true, body_parser: :json

  FRESHDESK_PRODUCT_FILTER = 'FRESHDESK_EMAIL'.freeze

  def perform(sqs_msg, _args)
    msg = JSON.parse(sqs_msg.body)
    data = msg['data'].deep_symbolize_keys
    return unless validate_params(data[:payload])

    begin
      account_id = data[:account_id]
      meta = msg['meta'].deep_symbolize_keys
      # remove milliseconds from timestamp since Time.at takes number of seconds since epoch
      time = Time.at(meta[:central][:collected_at] / 1000).in_time_zone
      process_email_rate_limiting(account_id, time)
    end
  rescue StandardError => e
    NewRelic::Agent.notice_error(e, description: "Error while processing Email Rate Limiting message #{e}")
    Rails.logger.error "Error while processing Email Rate Limiting message :: #{account_id} :: #{e.message} :: #{e.backtrace[0..10]}"
  end

  private

    def validate_params(payload)
      product = payload.try(:[], :product)
      product == FRESHDESK_PRODUCT_FILTER
    end
end
