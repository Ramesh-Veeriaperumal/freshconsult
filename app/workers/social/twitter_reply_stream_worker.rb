module Social
  class TwitterReplyStreamWorker < BaseWorker

    
    include Social::Twitter::Constants
    include Social::Constants
    include Gnip::Constants
    sidekiq_options :queue => :gnip_reply_stream, :retry => 0, :backtrace => true, :failures => :exhausted

    def perform(msg)
      return unless Rails.env.production? #Dont let replay run for non-production environments

      queue = $sqs_twitter
      source = SOURCE[:twitter]
      client = Gnip::ReplayClient.new(source, queue, options)
      response = client.start_replay

      unless response
        $redis_others.lpush(GNIP_DISCONNECT_LIST,
                                [options[:start_time],options[:end_time]].to_json)
        options.merge!(:environment => Rails.env)
        notification_topic = SNS["social_notification_topic"]
        DevNotification.publish(notification_topic, "Replay Stream Failed", options.to_json)
      end
    end
  end
end