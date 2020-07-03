class Ryuken::EmailRateLimitingWorker
  include Shoryuken::Worker
  include EmailRateLimitHelper
  include Redis::OthersRedis

  shoryuken_options queue: SQS[:email_rate_limiting_queue], auto_delete: true, body_parser: :json

  FRESHDESK_PRODUCT_FILTER = 'FRESHDESK_EMAIL'.freeze

  def perform(sqs_msg, _args)
    data = JSON.parse(sqs_msg.body)['data']
    data.deep_symbolize_keys!
    return unless validate_params(data[:payload])

    begin
      account_id = data[:account_id]
      time = Time.now.in_time_zone
      hour = time.hour
      min = time.min
      sec = time.sec
      # divide 1 hr in 4 quadrants of 15 min
      quadrant = min / 15 + 1
      # set expiry as 15 min plus remaining time in current quadrant from Time.now
      expiry = 30.minutes - (min % 15).minutes - sec.seconds
      process_email_rate_limiting(expiry, hour, quadrant, account_id)
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
