class Throttler::WebhookThrottler < Throttler::BaseWorker
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Sidekiq::Worker

  sidekiq_options :queue => 'webhook_throttler', 
    :retry => 0, 
    :dead => true, 
    :failures => :exhausted
    
  def initialize
    @throttle_duration = 1.hour
    @worker = "WebhookWorker".constantize
  end

  protected
    def key(throttler_args)
      WEBHOOK_THROTTLER % {:account_id => throttler_args[:args]["account_id"]}
    end

    def throttle_limit
      1000
    end

    def limit_exceeded_callback(throttle_expiration, throttler_args)
      limit_exceeded_key = WEBHOOK_THROTTLER_LIMIT_EXCEEDED % {:account_id => throttler_args[:args]["account_id"]}
      unless redis_key_exists?(limit_exceeded_key)
        set_others_redis_key(limit_exceeded_key, true, throttle_expiration)
        raise_notification(throttler_args[:args]["account_id"])
      end
    end
  private
    def raise_notification account_id
      notification_topic = SNS["dev_ops_notification_topic"]
      subject = "Webhook Throttler limit exceed for Account ID : #{account_id}"
      options = { :account_id => account_id, :environment => Rails.env }
      DevNotification.publish(notification_topic, subject, options.to_json)
    end
end
