sqs_config = YAML::load(ERB.new(File.read("#{Rails.root}/config/sqs.yml")).result)

SQS = (sqs_config[Rails.env] || sqs_config).symbolize_keys

# Add loop if more queues
#
SQS_V2_QUEUE_URLS = {
  SQS[:search_etl_queue] => AwsWrapper::SqsV2.queue_url(SQS[:search_etl_queue])
}

begin
  #Global SQS client
  $sqs_client = AWS::SQS.new.client
  # current_pod = PodConfig['CURRENT_POD']

  #pod specific sqs queue facebook
  # $sqs_facebook_global =  AWS::SQS.new.queues.named(SQS[:facebook_realtime_queue])
  # $sqs_facebook =  AWS::SQS.new.queues.named(current_pod + '_' + SQS[:facebook_realtime_queue])
  
  $sqs_facebook =  AWS::SQS.new.queues.named(SQS[:facebook_realtime_queue])

  # Initializing global variable polling the tweets from sqs - pod specific
  # $sqs_twitter_global = AWS::SQS.new.queues.named(SQS[:twitter_realtime_queue])
  # $sqs_twitter = AWS::SQS.new.queues.named(current_pod + '_' + SQS[:twitter_realtime_queue])
  
  $sqs_twitter = AWS::SQS.new.queues.named(SQS[:twitter_realtime_queue])

  # custom mailbox sqs queue
  $sqs_mailbox = AWS::SQS.new.queues.named(SQS[:custom_mailbox_realtime_queue])
    
  # Reports etl msgs queue
  $sqs_reports_etl = AWS::SQS.new.queues.named(SQS[:reports_etl_msg_queue])

  # Reports Service Export
  $sqs_reports_service_export = AWS::SQS.new.queues.named(SQS[:reports_service_export_queue])

  # Reports helpkit Export
  $sqs_reports_helpkit_export = AWS::SQS.new.queues.named(SQS[:helpdesk_reports_export_queue])  
  
rescue => e
  puts "AWS::SQS connection establishment failed."
end
