class ManualPublishWorker < RabbitmqWorker
  sidekiq_options queue: 'manual_publish', retry: 5, dead: true, failures: :exhausted

  private

    def enqueue_search_sqs(message)
      Ryuken::DelayedSearchSplitter.perform_async(message)
    end

    def enqueue_analytics_sqs(message)
      Ryuken::DelayedAnalyticsCountPerformer.perform_async(message)
    end

end
