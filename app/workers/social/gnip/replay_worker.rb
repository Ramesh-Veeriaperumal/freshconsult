class Social::Gnip::ReplayWorker < BaseWorker
  
  include Social::Twitter::Constants
  include Social::Constants
  include Gnip::Constants

  sidekiq_options :queue => :twitter_replay_worker, :retry => 0, :failures => :exhausted

  def perform(options)
    return unless Rails.env.production? #Dont let replay run for non-production environments

    queue    = SQS[:twitter_realtime_queue]
    source   = SOURCE[:twitter]
    client   = Gnip::ReplayClient.new(source, queue, options)
    response = client.start_replay

    unless response
      $redis_others.perform_redis_op("lpush", GNIP_DISCONNECT_LIST,
                          [options['start_time'],options['end_time']].to_json)
      options.merge!(:environment => Rails.env)
      notification_topic = SNS["social_notification_topic"]
      DevNotification.publish(notification_topic, "Replay Stream Failed", options.to_json)
    end
  end
end
