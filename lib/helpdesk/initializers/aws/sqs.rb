sqs_config = YAML::load(ERB.new(File.read("#{Rails.root}/config/sqs.yml")).result)

SQS = (sqs_config[Rails.env] || sqs_config).symbolize_keys

begin
  #Global SQS client
  $sqs_client = AWS::SQS.new.client

  #for sqs queue facebook
  $sqs_facebook = AwsWrapper::Sqs.new(SQS[:facebook_realtime_queue])

  # Initializing global variable polling the tweets from sqs
  $sqs_twitter = AWS::SQS.new.queues.named(SQS[:twitter_realtime_queue])

  # ticket auto refresh sqs queue
  $sqs_autorefresh = AwsWrapper::Sqs.new(SQS[:auto_refresh_realtime_queue])

  # custom mailbox sqs queue
  $sqs_mailbox = AWS::SQS.new.queues.named(SQS[:custom_mailbox_realtime_queue])
  
  # Reports export queue
  $sqs_reports_export = AWS::SQS.new.queues.named(SQS[:helpdesk_reports_export_queue])
  
  # Reports etl msgs queue
  $sqs_reports_etl = AWS::SQS.new.queues.named(SQS[:reports_etl_msg_queue])

rescue => e
  puts "AWS::SQS connection establishment failed."
end

