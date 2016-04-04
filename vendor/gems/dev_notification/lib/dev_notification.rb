module DevNotification

  #Create Topic
  def self.create_dev_notification_topic(name, recepients, backup=false)
    topic = $sns_client.create_topic({:name => name})
    subscription_list = $sns_client.list_subscriptions_by_topic({:topic_arn => topic[:topic_arn]})
    if subscription_list[:subscriptions].blank?
      email_subscription(recepients, topic)
      sqs_subscription(name, topic) if backup
    else
      puts "Subscriptions already present for the topic #{name} => #{subscription_list.inspect}"
    end
  end

  def self.publish(name, subject, message)
    args = {
      :name => name,
      :subject => subject,
      :message => message
    }
    DevNotificationWorker.perform_async(args)
  end

  #Delete topic
  def self.delete_dev_notification_topic(name)
    topic = $sns_client.create_topic({:name => name})
    $sns_client.delete_topic(:topic_arn => topic[:topic_arn])
  end

  private
    def self.create_policy(name, sqs_arn, sns_arn)
      policy = {
        "Id" => "Policy_#{name}_#{Time.now.to_i}",
        "Statement" => [
          {
            "Sid" => "Stmt_#{name}_#{Time.now.to_i}",
            "Action" => ["sqs:SendMessage"],
            "Effect" => "Allow",
            "Resource" => sqs_arn,
            "Condition" => {
              "ArnEquals" => {
                "aws:SourceArn" => sns_arn
                }
            },
            "Principal" => {
              "AWS" => ["*"]
            }
          }
        ]
      }
      return policy.to_json
    end
    
    def self.email_subscription(recepients, topic)
      recepients.each do |email|
        subscribe_params = {
          :topic_arn => topic[:topic_arn],
          :protocol => "email",
          :endpoint => email
        }
        $sns_client.subscribe(subscribe_params)
      end
      puts "Successfully subscribed for email"
    end
    
    def self.sqs_subscription(name, topic)
      sqs_prefix = "sns_subscriber"
      sqs_name = "#{sqs_prefix}_#{name}"

      #create a SQS queue to backup on notifications
      $sqs_client.create_queue({:queue_name => sqs_name, :attributes => {"MessageRetentionPeriod" => "1209600"}})
      queue = AWS::SQS.new.queues.named(sqs_name)

      #Add permissions to the SQS queue
      policy = create_policy(name, queue.arn, topic[:topic_arn])
      queue.policy = policy

      #Subscibe to the SQS queue
      subscribe_params = {
        :topic_arn => topic[:topic_arn],
        :protocol => "sqs",
        :endpoint => queue.arn
      }
      $sns_client.subscribe(subscribe_params)
      puts "Successfully subscribed for SQS"
    end
end
