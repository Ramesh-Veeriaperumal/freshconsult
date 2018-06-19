sqs_config = YAML.load(ERB.new(File.read("#{Rails.root}/config/sqs.yml")).result)

SQS = (sqs_config[Rails.env] || sqs_config).symbolize_keys

# Global SQS client
begin
  $sqs_client = AWS::SQS.new.client
rescue => e
  puts "AWS::SQS connection establishment failed. - #{e.message}"
end

# List of SQS QUEUES for which, want access url as global variables
# keys => name in yml, values => global variable to access SQS Queue url.
GLOBAL_SQS_QUEUE_URLS = {
  :facebook_realtime_queue        => 'sqs_facebook',
  :channel_framework_services     => 'channel_framework_services',
  :custom_mailbox_status          => 'custom_mailbox_status',
  :fb_message_realtime_queue      => 'sqs_facebook_messages',
  :custom_mailbox_realtime_queue  => 'sqs_mailbox',
  :cti_call_queue                 => 'sqs_cti',
  :reports_service_export_queue   => 'sqs_reports_service_export',
  :helpdesk_reports_export_queue  => 'sqs_reports_helpkit_export',
  :freshfone_call_notifier_queue  => 'freshfone_call_notifier',
  :freshfone_call_tracker         => 'sqs_freshfone_tracker',
  :scheduled_ticket_export_config => 'sqs_scheduled_ticket_export',
  :fd_email_failure_reference     => 'sqs_email_failure_reference'
}

GLOBAL_SQS_QUEUE_URLS.each do |queue_name, variable_name|
  begin
    if SQS[queue_name].present?
      eval "$#{variable_name} = AWS::SQS.new.queues.named(SQS[queue_name])"
    else
      puts "yml value not found for #{queue_name}"
    end
  rescue => e
    puts "Error in fetching URL for SQS Queue #{SQS[queue_name]} - error #{e.message}"
    NewRelic::Agent.notice_error(e, {:description => "Error in fetching URL for SQS Queue #{SQS[queue_name]} - error #{e.message}"})
  end
end

# SQS v2 Queues list
 SQS_V2_QUEUES =  [
  :search_etl_queue, :count_etl_queue, :reports_etl_msg_queue, :iris_etl_msg_queue,
  :activity_queue, :sqs_es_index_queue, :cti_screen_pop, :auto_refresh_queue,
  :auto_refresh_alb_queue, :agent_collision_alb_queue, :marketplace_app_queue,
  :free_customer_email_queue, :active_customer_email_queue, :trial_customer_email_queue,
  :default_email_queue, :email_dead_letter_queue, :agent_collision_queue,
  :collab_agent_update_queue, :collab_ticket_update_queue, :fd_email_failure_reference,
  :scheduled_ticket_export_queue, :scheduled_user_export_queue, :scheduled_company_export_queue,
  :scheduled_export_payload_enricher_queue, :fd_scheduler_reminder_todo_queue, :bot_feedback_queue
]

SQS_V2_QUEUE_URLS = {}
SQS_V2_QUEUES.each do |queue_name|
  begin
    if SQS[queue_name].present?
      SQS_V2_QUEUE_URLS[SQS[queue_name]] = AwsWrapper::SqsV2.queue_url(SQS[queue_name])
    else
      puts "yml value not found for #{queue_name}"
    end
  rescue => e
    puts "Error in fetching URL for SQS Queue #{SQS[queue_name]} - error #{e.message}"
    NewRelic::Agent.notice_error(e, {:description => "Error in fetching URL for SQS Queue #{SQS[queue_name]} - error #{e.message}"})
  end
end
SQS_V2_QUEUE_URLS.freeze

# TWITTER RELATED SQS QUEUES
begin
  # EUC polls from the region specifuc queue pushed from EU
  if S3_CONFIG[:region] == 'eu-central-1'
    $sqs_twitter = AWS::SQS.new.queues.named(SQS[:twitter_realtime_queue])
  # EU polls from the global queue, pushes it to region specific queues EU/EUC
  elsif S3_CONFIG[:region] == 'eu-west-1'
    $sqs_euc = AWS::SQS.new(
      :access_key_id => S3_CONFIG[:access_key_id_euc],
      :secret_access_key => S3_CONFIG[:secret_access_key_euc],
      :region => S3_CONFIG[:region_euc],
      :s3_signature_version => :v4)

    # Initializing global variable polling the tweets from sqs - pod specific
    $sqs_twitter_global = AWS::SQS.new.queues.named(SQS[:global_twitter_realtime_queue])
    $sqs_twitter        = AWS::SQS.new.queues.named(SQS[:twitter_realtime_queue])
    $sqs_twitter_eu     = AWS::SQS.new.queues.named(SQS[:twitter_realtime_queue_eu])
    $sqs_twitter_euc    = $sqs_euc.queues.named(SQS[:twitter_realtime_queue_euc])
  else
    # US & AU Polls dircetly from the global queue - No region specific queues
    $sqs_twitter  = AWS::SQS.new.queues.named(SQS[:twitter_realtime_queue])
  end

rescue => e
  puts "Error in fetching URL for twitter queues - #{e.message}"
  NewRelic::Agent.notice_error(e, {:description => "Error in fetching URL for twitter queues - #{e.message}"})
end
