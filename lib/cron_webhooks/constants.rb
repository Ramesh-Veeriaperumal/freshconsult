module CronWebhooks::Constants
  VALIDATION_CLASS = 'CronWebhooksValidation'.freeze

  MODES = %w[dryrun webhook].freeze
  DRYRUN = 'dryrun'.freeze
  TYPES = %w[paid free trial premium].freeze
  TASKS_REQUIRING_TYPES = %w[
    scheduler_sla
    scheduler_sla_reminder
    scheduler_supervisor
    account_cleanup_accounts_spam_cleanup
    scheduler_facebook
  ].freeze
  TASKS_REQUIRING_QUEUE_NAME = %w[sqs_monitor].freeze
  TASKS_REQUIRING_ACCOUNT_ID = %w[archive_automation].freeze
  TASKS_REQUIRING_SHARD_NAME = %w[archive_automation].freeze
  TRIGGER_FIELDS = %w[mode task_name type queue_name account_id shard_name].freeze
  CRON_JOB_SEMAPHORE = 'CRON_JOB_SEMAPHORE:%{task}:%{misc}'.freeze
  CONTROLLER = 'web_hooks_controller'.freeze
  CONTROLLER_SEMAPHORE_EXPIRY = 180

  MONITORED_QUEUES = %w[facebook_realtime_queue].freeze

  WORKER_ARGS_KEYS = %w[type task_name mode queue_name account_id shard_name].freeze

  TASK_MAPPING = {
    google_contacts_sync: {
      class_name: 'CronWebhooks::GoogleContactsSync',
      semaphore_expiry: 1.hour
    },
    scheduler_sla: {
      class_name: 'CronWebhooks::SchedulerSla',
      semaphore_expiry: 1.hour
    },
    scheduler_sla_reminder: {
      class_name: 'CronWebhooks::SchedulerSlaReminder',
      semaphore_expiry: 1.hour
    },
    scheduler_supervisor: {
      class_name: 'CronWebhooks::SchedulerSupervisor',
      semaphore_expiry: 1.hour
    },
    contacts_sync_trial: {
      class_name: 'CronWebhooks::ContactsSync',
      semaphore_expiry: 1.hour
    },
    contacts_sync_paid: {
      class_name: 'CronWebhooks::ContactsSync',
      semaphore_expiry: 1.hour
    },
    contacts_sync_free: {
      class_name: 'CronWebhooks::ContactsSync',
      semaphore_expiry: 1.hour
    },
    resque_watcher_check_load: {
      class_name: 'CronWebhooks::ResqueWatcherCheckLoad',
      semaphore_expiry: 1.hour
    },
    scheduler_facebook: {
      class_name: 'CronWebhooks::FacebookDm',
      semaphore_expiry: 1.hour
    },
    scheduler_custom_stream_twitter: {
      class_name: 'CronWebhooks::TwitterCustomStream',
      semaphore_expiry: 1.hour
    },
    spam_digest_mailer_queue: {
      class_name: 'CronWebhooks::SpamDigestMailer',
      semaphore_expiry: 1.hour
    },
    forum_moderation_create_tables: {
      class_name: 'CronWebhooks::ForumModerationCreateTables',
      semaphore_expiry: 1.hour
    },
    forum_moderation_drop_tables: {
      class_name: 'CronWebhooks::ForumModerationDropTables',
      semaphore_expiry: 1.hour
    },
    populate_spam_watcher_limits: {
      class_name: 'CronWebhooks::PopulateSpamWatcherLimits',
      semaphore_expiry: 1.hour
    },
    delayedjobs_watcher_failed_jobs: {
      class_name: 'CronWebhooks::DelayedJobsWatcher',
      semaphore_expiry: 1.hour
    },
    delayedjobs_watcher_total_jobs: {
      class_name: 'CronWebhooks::DelayedJobsWatcher',
      semaphore_expiry: 1.hour
    },
    delayedjobs_watcher_scheduled_jobs: {
      class_name: 'CronWebhooks::DelayedJobsWatcher',
      semaphore_expiry: 1.hour
    },
    delayedjobs_watcher_move_delayed_jobs: {
      class_name: 'CronWebhooks::DelayedJobsWatcher',
      semaphore_expiry: 1.hour
    },
    billing_info_enable_billing_info_update: {
      class_name: 'CronWebhooks::BillingInfoUpdate',
      semaphore_expiry: 1.hour
    },
    trial_subscriptions_rollback_trail_subscriptions_data: {
      class_name: 'CronWebhooks::RollbackTrialSubscriptionsData',
      semaphore_expiry: 1.hour
    },
    central_publisher_requeue: {
      class_name: 'CronWebhooks::RequeueCentralPublish',
      semaphore_expiry: 1.hour
    },
    sidekiq_bg_fetch_dead_jobs: {
      class_name: 'CronWebhooks::SidekiqDeadSetMailer',
      semaphore_expiry: 1.hour
    },
    failed_helpkit_feeds_requeue: {
      class_name: 'CronWebhooks::FailedHelpkitFeeds',
      semaphore_expiry: 1.hour
    },
    attachment_cleanup_user_draft_cleanup: {
      class_name: 'CronWebhooks::AttachmentUserDraftCleanup',
      semaphore_expiry: 1.hour
    },
    account_cleanup_accounts_spam_cleanup: {
      class_name: 'CronWebhooks::AccountSpamCleanup',
      semaphore_expiry: 1.hour
    },
    log_cloud_elements_sync_email_log: {
      class_name: 'CronWebhooks::LogCloudElementsSync',
      semaphore_expiry: 1.hour
    },
    ebay_daily_api_report_intimate: {
      class_name: 'CronWebhooks::EbayDailyApiReportIntimate',
      semaphore_expiry: 1.hour
    },
    redis_maintenance_set_timestamp: {
      class_name: 'CronWebhooks::RedisMaintenance',
      semaphore_expiry: 1.hour
    },
    redis_maintenance_slowlog_mailer: {
      class_name: 'CronWebhooks::RedisMaintenance',
      semaphore_expiry: 1.hour
    },
    reports_build_no_activity: {
      class_name: 'CronWebhooks::ReportsBuildNoActivity',
      semaphore_expiry: 1.hour
    },
    sitemap_generate: {
      class_name: 'CronWebhooks::SitemapGenerate',
      semaphore_expiry: 1.hour
    },
    traffic_switch_fetch_accounts: {
      class_name: 'CronWebhooks::TrafficSwitchFetchAccounts',
      semaphore_expiry: 1.hour
    },
    long_running_queries_check: {
      class_name: 'CronWebhooks::LongRunningQueriesCheck',
      semaphore_expiry: 1.hour
    },
    gnip_stream_maintenance: {
      class_name: 'CronWebhooks::GnipStreamMaintenance',
      semaphore_expiry: 1.hour
    },
    gnip_stream_replay: {
      class_name: 'CronWebhooks::GnipStreamReplay',
      semaphore_expiry: 1.hour
    },
    social_create_dynamoDb_tables: {
      class_name: 'CronWebhooks::SocialCreateDynamodbTables',
      semaphore_expiry: 1.hour
    },
    social_delete_dynamoDb_tables: {
      class_name: 'CronWebhooks::SocialDeleteDynamodbTables',
      semaphore_expiry: 1.hour
    },
    sqs_monitor: {
      class_name: 'CronWebhooks::SqsMonitor',
      semaphore_expiry: 1.hour
    },
    scheduled_task_trigger_upcoming: {
      class_name: 'CronWebhooks::ScheduledTask',
      semaphore_expiry: 1.hour
    },
    scheduled_task_trigger_dangling: {
      class_name: 'CronWebhooks::ScheduledTask',
      semaphore_expiry: 1.hour
    },
    scheduled_task_calculate_next_run_at: {
      class_name: 'CronWebhooks::ScheduledTask',
      semaphore_expiry: 1.hour
    },
    meta_data_check_data_consistency_check: {
      class_name: 'CronWebhooks::MetaDataCheck',
      semaphore_expiry: 1.hour
    },
    freshfone_failed_costs: {
      class_name: 'CronWebhooks::Freshfone',
      semaphore_expiry: 1.hour
    },
    freshfone_suspend: {
      class_name: 'CronWebhooks::Freshfone',
      semaphore_expiry: 1.hour
    },
    freshfone_renew_numbers: {
      class_name: 'CronWebhooks::Freshfone',
      semaphore_expiry: 1.hour
    },
    freshfone_suspension_reminder_3days: {
      class_name: 'CronWebhooks::Freshfone',
      semaphore_expiry: 1.hour
    },
    freshfone_suspension_reminder_15days: {
      class_name: 'CronWebhooks::Freshfone',
      semaphore_expiry: 1.hour
    },
    freshfone_freshfone_call_twilio_recording_delete: {
      class_name: 'CronWebhooks::Freshfone',
      semaphore_expiry: 1.hour
    },
    freshfone_failed_call_status_update: {
      class_name: 'CronWebhooks::Freshfone',
      semaphore_expiry: 1.hour
    },
    freshfone_failed_close_accounts: {
      class_name: 'CronWebhooks::Freshfone',
      semaphore_expiry: 1.hour
    },
    enable_omniroute_for_new_accounts: {
      class_name: 'CronWebhooks::EnableOmnirouteForNewAccounts',
      semaphore_expiry: 1.hour
    },
    archive_automation: {
      class_name: 'CronWebhooks::ArchiveAutomation',
      semaphore_expiry: 24.hours
    }
  }.freeze

  TASKS = TASK_MAPPING.keys.map(&:to_s).freeze

  SUPERVISOR_TASKS = {
    'trial' => {
      account_method: 'trial_accounts',
      class_name: 'Admin::TrialSupervisorWorker'
    },
    'paid' => {
      account_method: 'paid_accounts',
      class_name: 'Admin::SupervisorWorker'
    },
    'free' => {
      account_method: 'free_accounts',
      class_name: 'Admin::FreeSupervisorWorker'
    },
    'premium' => {
      account_method: 'active_accounts',
      class_name: 'Admin::PremiumSupervisorWorker'
    }
  }.freeze

  SLA_REMINDER_TASKS = {
    'trial' => {
      account_method: 'trial_accounts',
      class_name: 'Admin::Sla::Reminder::Trial'
    },

    'paid' => {
      account_method: 'paid_accounts',
      class_name: 'Admin::Sla::Reminder::Base'
    },

    'free' => {
      account_method: 'free_accounts',
      class_name: 'Admin::Sla::Reminder::Free'
    },

    'premium' => {
      account_method: 'active_accounts',
      class_name: 'Admin::Sla::Reminder::Premium'
    }
  }.freeze

  SLA_TASKS = {
    'trial' => {
      account_method: 'trial_accounts',
      class_name: 'Admin::Sla::Escalation::Trial'
    },

    'paid' => {
      account_method: 'paid_accounts',
      class_name: 'Admin::Sla::Escalation::Base'
    },

    'free' => {
      account_method: 'free_accounts',
      class_name: 'Admin::Sla::Escalation::Free'
    },

    'premium' => {
      account_method: 'active_accounts',
      class_name: 'Admin::Sla::Escalation::Premium'
    }
  }.freeze

  CONTACTS_SYNC_TASKS = {
    'trial' => {
      account_method: 'trial_accounts',
      class_name: 'Integrations::ContactsSync::Trial'
    },

    'paid' => {
      account_method: 'paid_accounts',
      class_name: 'Integrations::ContactsSync::Paid'
    },

    'free' => {
      account_method: 'free_accounts',
      class_name: 'Integrations::ContactsSync::Free'
    }
  }.freeze

  FACEBOOK_TASKS = {
    'trial' => {
      account_method: 'trail_acc_pages',
      class_name: 'Social::TrialFacebookWorker'
    },
    'paid' => {
      account_method: 'paid_acc_pages',
      class_name: 'Social::FacebookWorker'
    }
  }.freeze

  QUEUE_WATCHER_RULE = {
    threshold: {
      'observer_worker' => 5000,
      'update_ticket_states_queue' => 5000,
      'premium_supervisor_worker' => 5000,
      'es_index_queue' => 10_000,
      'sla_worker' => 25_000,
      'free_sla_worker' => 25_000,
      'trail_sla_worker' => 25_000,
      'Salesforcequeue' => 1000
    },
    except: %w[supervisor_worker gamification_ticket_quests gamification_ticket_score helpdesk_note_body_queue gamification_user_score livechat_queue]
  }.freeze

  PAGER_DUTY_FREQUENCY_SECS = Rails.env.production? ? 18_000 : 900 # 5 hours : # 15 mins
  PAGERDUTY_QUEUES = %w[observer_worker update_ticket_states_queue].freeze
end
