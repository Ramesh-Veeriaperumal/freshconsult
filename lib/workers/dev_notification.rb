class Workers::DevNotification
  #extend Resque::AroundPerform

  @queue = 'dev_notification_worker'

  def self.perform args
    name = args["name"]
    subject = args["subject"]
    message = args["message"]

    topic = $sns_client.create_topic({:name => name})
    $sns_client.publish(:topic_arn => topic[:topic_arn], :subject => subject, :message => message) unless Rails.env.test?
  end

end
