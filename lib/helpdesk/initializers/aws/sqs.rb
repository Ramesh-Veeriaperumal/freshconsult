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
  :twitter_realtime_queue         => 'sqs_twitter',
  :channel_framework_services     => 'channel_framework_services',
  :custom_mailbox_status          => 'custom_mailbox_status',
  :fb_message_realtime_queue      => 'sqs_facebook_messages',
  :cti_call_queue                 => 'sqs_cti',
  :reports_service_export_queue   => 'sqs_reports_service_export',
  :helpdesk_reports_export_queue  => 'sqs_reports_helpkit_export',
  :freshfone_call_notifier_queue  => 'freshfone_call_notifier',
  :freshfone_call_tracker         => 'sqs_freshfone_tracker',
  :scheduled_ticket_export_config => 'sqs_scheduled_ticket_export',
  :fd_email_failure_reference     => 'sqs_email_failure_reference'
}

CROSS_ACCOUNT_SQS_DIRECT_URLS = [:custom_mailbox_realtime_queue]

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
end unless Rails.env.development?

# SQS v2 Queues list
 SQS_V2_QUEUES =  [
  :search_etl_queue, :count_etl_queue, :analytics_etl_queue, :reports_etl_msg_queue, :iris_etl_msg_queue,
  :activity_queue, :sqs_es_index_queue, :cti_screen_pop, :auto_refresh_queue,
  :auto_refresh_alb_queue, :agent_collision_alb_queue, :marketplace_app_queue,
  :free_customer_email_queue, :active_customer_email_queue, :trial_customer_email_queue,
  :default_email_queue, :email_dead_letter_queue, :agent_collision_queue,
  :collab_agent_update_queue, :collab_ticket_update_queue, :fd_email_failure_reference,
  :scheduled_ticket_export_queue, :scheduled_user_export_queue, :scheduled_company_export_queue,
  :scheduled_export_payload_enricher_queue, :fd_scheduler_reminder_todo_queue, :bot_feedback_queue,
  :fd_scheduler_export_cleanup_queue, :spam_trash_delete_free_acc_queue, :spam_trash_delete_paid_acc_queue,
  :fd_scheduler_downgrade_policy_reminder_queue, :suspended_account_cleanup_queue,
  :search_etlqueue_maintenance, :count_etl_queue_maintenance, :analytics_etl_queue_maintenance
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
end unless Rails.env.development?

CROSS_ACCOUNT_SQS_DIRECT_URLS.each do |queue_name|
  if SQS[queue_name].present?
    SQS_V2_QUEUE_URLS[queue_name.to_s] = SQS[queue_name]
  else
    puts "CROSS_ACCOUNT_SQS_DIRECT_URLS: yml value not found for #{queue_name}"
  end
end unless Rails.env.development?

SQS_V2_QUEUE_URLS.freeze

