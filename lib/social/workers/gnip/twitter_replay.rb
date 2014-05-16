class Social::Workers::Gnip::TwitterReplay
  include Social::Twitter::Constants
  include Social::Constants
  include Gnip::Constants

  @queue = "twitter_replay_worker"

  def self.perform(options)
    return unless Rails.env.production? #Dont let replay run for non-production environments

    queue    = $sqs_twitter
    source   = SOURCE[:twitter]
    client   = Gnip::ReplayClient.new(source, queue, options)
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
