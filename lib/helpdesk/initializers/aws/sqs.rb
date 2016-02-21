sqs_config = YAML::load(ERB.new(File.read("#{Rails.root}/config/sqs.yml")).result)

SQS = (sqs_config[Rails.env] || sqs_config).symbolize_keys

begin
  #Global SQS client
  $sqs_client = AWS::SQS.new.client

  #for sqs queue facebook
  $sqs_facebook = AWS::SQS.new.queues.named(SQS[:facebook_realtime_queue])

  # Initializing global variable polling the tweets from sqs
  $sqs_twitter = AWS::SQS.new.queues.named(SQS[:twitter_realtime_queue])

  # custom mailbox sqs queue
  $sqs_mailbox = AWS::SQS.new.queues.named(SQS[:custom_mailbox_realtime_queue])
    
  # Reports etl msgs queue
  $sqs_reports_etl = AWS::SQS.new.queues.named(SQS[:reports_etl_msg_queue])

  # Reports Service Export
  $sqs_reports_service_export = AWS::SQS.new.queues.named(SQS[:reports_service_export_queue])

  # Reports helpkit Export
  $sqs_reports_helpkit_export = AWS::SQS.new.queues.named(SQS[:helpdesk_reports_export_queue])  

  # AWS SDK V2 SQS Client
  $sqs_v2_client = (Rails.env.development? || Rails.env.test?) ? 
    Aws::SQS::Client.new(endpoint: 'http://localhost:4568', access_key_id: 'dummy', secret_access_key: 'dummy') : 
    Aws::SQS::Client.new(region: S3_CONFIG[:region],access_key_id: S3_CONFIG[:access_key_id],secret_access_key: S3_CONFIG[:secret_access_key])
  
rescue => e
  puts "AWS::SQS connection establishment failed."
end
