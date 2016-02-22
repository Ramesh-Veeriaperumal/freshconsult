class PremiumWebhookWorker < WebhookWorker

  sidekiq_options :queue => 'premium_webhook_worker',
    :retry => 0,
    :dead => true,
    :failures => :exhausted

    def initialize
      @throttler = "Throttler::PremiumWebhookThrottler".constantize
    end
end
