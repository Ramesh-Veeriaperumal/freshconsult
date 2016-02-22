class Throttler::PremiumWebhookThrottler < Throttler::WebhookThrottler

  sidekiq_options :queue => 'premium_webhook_throttler',
    :retry => 0,
    :dead => true,
    :failures => :exhausted

    def initialize
      @throttle_duration = 1.hour
      @worker = "PremiumWebhookWorker".constantize
    end

end
