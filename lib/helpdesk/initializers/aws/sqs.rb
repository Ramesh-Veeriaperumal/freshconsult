sqs_config = YAML.load(ERB.new(File.read("#{Rails.root}/config/sqs.yml")).result)

SQS = (sqs_config[Rails.env] || sqs_config).symbolize_keys

begin
  # Global SQS client
  $sqs_client = AWS::SQS.new.client

  $sqs_facebook = AWS::SQS.new.queues.named(SQS[:facebook_realtime_queue])

  $channel_framework_services =  AWS::SQS.new.queues.named(SQS[:channel_framework_services])

  $sqs_facebook_messages = AWS::SQS.new.queues.named(SQS[:fb_message_realtime_queue])

  ##################### SQS RELATED TO TWITTER STARTS #########################

  #EUC polls from the region specifuc queue pushed from EU
  if S3_CONFIG[:region] == 'eu-central-1'
    $sqs_twitter  = AWS::SQS.new.queues.named( S3_CONFIG[:region] + '_' + SQS[:twitter_realtime_queue])

    #EU polls from the global queue, pushes it to region specific queues EU/EUC
  elsif S3_CONFIG[:region] == 'eu-west-1'
    $sqs_euc = AWS::SQS.new(
      access_key_id: S3_CONFIG[:access_key_id_euc],
      secret_access_key: S3_CONFIG[:secret_access_key_euc],
      region: S3_CONFIG[:region_euc],
      s3_signature_version: :v4
    )

    # Initializing global variable polling the tweets from sqs - pod specific
    $sqs_twitter_global = AWS::SQS.new.queues.named(SQS[:twitter_realtime_queue])
    $sqs_twitter        = AWS::SQS.new.queues.named(S3_CONFIG[:region] + '_' + SQS[:twitter_realtime_queue])
    $sqs_twitter_euc    = $sqs_euc.queues.named(S3_CONFIG[:region_euc] + '_' + SQS[:twitter_realtime_queue])
  else
    #US & AU Polls dircetly from the global queue - No region specific queues
    $sqs_twitter  = AWS::SQS.new.queues.named(SQS[:twitter_realtime_queue])
  end

  ##################### SQS RELATED TO TWITTER ENDS #########################

  # custom mailbox sqs queue
  $sqs_mailbox = AWS::SQS.new.queues.named(SQS[:custom_mailbox_realtime_queue])

  # cti ticket creation queue
  $sqs_cti = AWS::SQS.new.queues.named(SQS[:cti_call_queue])

  # Reports Service Export
  $sqs_reports_service_export = AWS::SQS.new.queues.named(SQS[:reports_service_export_queue])

  # Reports helpkit Export
  $sqs_reports_helpkit_export = AWS::SQS.new.queues.named(SQS[:helpdesk_reports_export_queue])

  # Freshfone Call Notifier
  $freshfone_call_notifier = AWS::SQS.new.queues.named(SQS[:freshfone_call_notifier_queue])

  # Freshfone Call Tracker
  $sqs_freshfone_tracker = AWS::SQS.new.queues.named(SQS[:freshfone_call_tracker])

  # Scheduled Ticket Export
  $sqs_scheduled_ticket_export = AWS::SQS.new.queues.named(SQS[:scheduled_ticket_export_config])

  # Email failure reference from activities service
  $sqs_email_failure_reference = AWS::SQS.new.queues.named(SQS[:fd_email_failure_reference])

  # Add loop if more queues
  #
  SQS_V2_QUEUE_URLS = {
    SQS[:search_etl_queue]            => AwsWrapper::SqsV2.queue_url(SQS[:search_etl_queue]),
    SQS[:count_etl_queue]             => AwsWrapper::SqsV2.queue_url(SQS[:count_etl_queue]),
    SQS[:reports_etl_msg_queue]       => AwsWrapper::SqsV2.queue_url(SQS[:reports_etl_msg_queue]),
    SQS[:iris_etl_msg_queue]          => AwsWrapper::SqsV2.queue_url(SQS[:iris_etl_msg_queue]),
    SQS[:activity_queue]              => AwsWrapper::SqsV2.queue_url(SQS[:activity_queue]),
    SQS[:sqs_es_index_queue]          => AwsWrapper::SqsV2.queue_url(SQS[:sqs_es_index_queue]),
    SQS[:cti_screen_pop]              => AwsWrapper::SqsV2.queue_url(SQS[:cti_screen_pop]),
    SQS[:auto_refresh_queue]          => AwsWrapper::SqsV2.queue_url(SQS[:auto_refresh_queue]),
    SQS[:auto_refresh_alb_queue]    => AwsWrapper::SqsV2.queue_url(SQS[:auto_refresh_alb_queue]),
    SQS[:agent_collision_alb_queue] => AwsWrapper::SqsV2.queue_url(SQS[:agent_collision_alb_queue]),
    SQS[:marketplace_app_queue]     => AwsWrapper::SqsV2.queue_url(SQS[:marketplace_app_queue]),
    SQS[:free_customer_email_queue]   => AwsWrapper::SqsV2.queue_url(SQS[:free_customer_email_queue]),
    SQS[:active_customer_email_queue] => AwsWrapper::SqsV2.queue_url(SQS[:active_customer_email_queue]),
    SQS[:trial_customer_email_queue]  => AwsWrapper::SqsV2.queue_url(SQS[:trial_customer_email_queue]),
    SQS[:default_email_queue]         => AwsWrapper::SqsV2.queue_url(SQS[:default_email_queue]),
    SQS[:email_dead_letter_queue]     => AwsWrapper::SqsV2.queue_url(SQS[:email_dead_letter_queue]),
    SQS[:agent_collision_queue] => AwsWrapper::SqsV2.queue_url(SQS[:agent_collision_queue]),
    SQS[:collab_agent_update_queue] => AwsWrapper::SqsV2.queue_url(SQS[:collab_agent_update_queue]),
    SQS[:collab_ticket_update_queue] => AwsWrapper::SqsV2.queue_url(SQS[:collab_ticket_update_queue]),
    SQS[:fd_email_failure_reference] => AwsWrapper::SqsV2.queue_url(SQS[:fd_email_failure_reference]),
    SQS[:scheduled_ticket_export_queue] => AwsWrapper::SqsV2.queue_url(SQS[:scheduled_ticket_export_queue]),
    SQS[:scheduled_user_export_queue] => AwsWrapper::SqsV2.queue_url(SQS[:scheduled_user_export_queue]),
    SQS[:scheduled_company_export_queue] => AwsWrapper::SqsV2.queue_url(SQS[:scheduled_company_export_queue]),
    SQS[:scheduled_export_payload_enricher_queue] => AwsWrapper::SqsV2.queue_url(SQS[:scheduled_export_payload_enricher_queue])
  }.freeze

rescue => e
  Rails.logger.debug "AWS::SQS connection establishment failed. - #{e.message}"
  Rails.logger.debug e.backtrace
ensure
  SQS_V2_QUEUE_URLS ||= {}.freeze
end
