# Based on helpkit_recipes/blob/shell-master/sidekiq/recipes/

class SidekiqConfig
  def self.get_settings(node)
    settings = {}
    settings[:utility_name] = 'sidekiq'

    layers = Array::new()
    layers = node[:opsworks][:instance][:layers]

    if layers.any? { |layer| layer.include?("fc-bg-sidekiq-hard-delete")}
      settings[:workers] = node[:cpu][:total]
      case node[:cpu][:total]
      when 4
        settings[:memory] = 5170
      when 8
        settings[:memory] = 3072
      end
    end

    settings[:redis_pool_size]  = 25
    settings[:verbose]      = true       # Verbose
    settings[:namespace]    = 'sidekiq'
    # include_attribute "redis"
    # include_attribute 'global::default'

    return settings
  end

  def self.setup(node, opsworks, options, sidekiq_in_templ, sidekiq_monitrc_templ)
    case node[:ymls][:pods][:current_pod]
    when node[:ymls][:pods][:global_pod]
      SidekiqConfigUsEast::setup(node, opsworks, options, sidekiq_in_templ, sidekiq_monitrc_templ)
    else
      SidekiqConfigStandard::setup(node, opsworks, options, sidekiq_in_templ, sidekiq_monitrc_templ)
    end
  end
end

class SidekiqConfigUsEast
  #instance prefixes
  NORMAL_SIDEKIQ           = "sidekiq-normal-"
  SLA_SIDEKIQ              = "sidekiq-sla-"
  SUPERVISOR_SIDEKIQ       = "sidekiq-supervisor-"
  SOCIAL_SIDEKIQ           = "sidekiq-social-"
  REPORTS_SIDEKIQ          = "sidekiq-reports-"
  SEARCH_SIDEKIQ           = "sidekiq-search-"
  FRESHFONE_SIDEKIQ        = "sidekiq-freshfone-"
  OBSERVER_SIDEKIQ         = "sidekiq-observer-"
  TICKETS_SIDEKIQ          = "sidekiq-tickets-"
  PUBLISH_SIDEKIQ          = "sidekiq-publish-"
  SELECT_ALL_SIDEKIQ       = "sidekiq-select-all-"
  INTEGRATIONS_SIDEKIQ     = "sidekiq-integrations-"
  DISPATCHER_SIDEKIQ       = "sidekiq-dispatcher-"
  WEBHOOK_SIDEKIQ          = "sidekiq-webhook-"
  RIAK_SIDEKIQ             = "sidekiq-riak-"
  EXPORT_SIDEKIQ           = "sidekiq-exports-"
  DELAYEDJOB_SIDEKIQ       = "sidekiq-delayed-jobs-"
  PAIDJOB_SIDEKIQ          = "sidekiq-paid-jobs-"
  ROUND_ROBIN_SIDEKIQ      = "sidekiq-round-robin-"
  MANUAL_PUBLISH_SIDEKIQ   = "sidekiq-manual-publish-"
  ALL_SIDEKIQ              = "sidekiq-all-1"
  COMMON_SIDEKIQ           = "sidekiq-common-"
  BULKSCHEDULED_SIDEKIQ    = ["sidekiq-bulk-scheduled-", "sidekiq-bulkscheduled"]
  CENTRAL_REALTIME_SIDEKIQ = "sidekiq-central-realtime-"

  #staging falcon common sidekiq
  # FALCON_COMMON_SIDEKIQ    = "fc-bg-sidekiq-common-"
  FRESHCALLER_SIDEKIQ      = "sidekiq-freshcaller-"

  REALTIME_SIDEKIQ         = "sidekiq-realtime-"
  SCHEDULED_SIDEKIQ        = "sidekiq-scheduled-"
  MAINTAINENCE_SIDEKIQ     = "sidekiq-maintainence-"
  FREE_SIDEKIQ             = "sidekiq-free-"
  EMAIL_SIDEKIQ            = "sidekiq-email-"
  TRIAL_SIDEKIQ            = "sidekiq-trial-"
  SPAM_SIDEKIQ             = "sidekiq-spam-"
  MOVED_SIDEKIQ            = "sidekiq-moved-"
  CENTRAL_REALTIME_SIDEKIQ = "sidekiq-central-realtime-"
  MAILBOXJOB_SIDEKIQ       = "sidekiq-mailbox-jobs-"
  BULK_API_SIDEKIQ         = "sidekiq-bulk-api-"

  # FALCON_OCCASIONAL        = "sidekiq-fc-occasional"
  GAMIFICATION_SIDEKIQ     = "sidekiq-gamification-"
  COMMUNITY_SIDEKIQ        = "sidekiq-community-"
  SUBSCRIPTION_SIDEKIQ     = "sidekiq-subscription-"
  HARD_DELETE_SIDEKIQ      = "sidekiq-hard-delete-"
  CRON_SIDEKIQ             = 'sidekiq-cron-'

  DEDICATED_REALTIME       = "sidekiq-dedicated-realtime"
  DEDICATED_BULK           = "sidekiq-dedicated-bulk"
  DEDICATED_EMAIL          = "sidekiq-dedicated-email"
  DEDICATED_OCCASIONAL     = "sidekiq-dedicated-occasional"
  DEDICATED_CENTRAL        = "sidekiq-dedicated-central"
  DEDICATED_SCHEDULED      = "sidekiq-dedicated-scheduled"
  DEDICATED_COMMON         = "sidekiq-dedicated-common"

  # new classifications
  OCCASIONAL_SIDEKIQ       = 'sidekiq-occasional-'.freeze
  FREQUENT_SIDEKIQ         = 'sidekiq-frequent-'.freeze
  MAINTENANCE_SIDEKIQ      = 'sidekiq-maintenance-'.freeze
  ARCHIVE_SIDEKIQ          = 'sidekiq-archive-'.freeze
  EXTERNAL_SIDEKIQ         = 'sidekiq-external-'.freeze
  LONG_RUNNING             = 'sidekiq-longrunning-'.freeze


  DEDICATED_INSTANCE_LIST  = [DEDICATED_REALTIME, DEDICATED_BULK, DEDICATED_EMAIL, DEDICATED_OCCASIONAL,DEDICATED_CENTRAL, DEDICATED_SCHEDULED, DEDICATED_COMMON]

  # Based on helpkit_recipes/blob/shell-master/sidekiq/recipes/useast1_setup.rb
  def self.setup(node, opsworks, options, sidekiq_in_templ, sidekiq_monitrc_templ)
    require 'enumerator'

    puts "Setting up sidekiq"

    pool = get_pool(node)

    queues = queue_priorities(pool)

    puts "Queues in this instance: #{queues.inspect}"

    worker_count = queues.size

    # bin script
    # /usr/bin/sidekiq_wrapper is part of docker itself

    # monit
    File.open("/etc/monit.d/bg/sidekiq_helpkit.monitrc", 'w') do |f|
      @app_name     = "helpkit"
      @workers      = worker_count
      @environment = node[:opsworks][:environment]
      @memory_limit = node[:sidekiq][:memory] || 3072 # MB
      f.write(Erubis::Eruby.new(File.read(sidekiq_monitrc_templ)).result(binding))
    end

    # yml files
    worker_count.times do |count|
      actual_queues = queues[count]

      instances_list = DEDICATED_INSTANCE_LIST
      if instances_list.any? {|instance_name| node[:opsworks][:instance][:hostname].include?(instance_name) }
        layer = node[:opsworks][:instance][:layers].first
        account_id = layer.split("-").last
        actual_queues = actual_queues.collect{ |queue_name| ("#{queue_name}_#{account_id}") }
      end

      out = File.join(options[:outdir], "sidekiq_client_#{count}.yml")
      File.open(out, 'w') do |f|
        @environment = node[:opsworks][:environment]
        @queues      = actual_queues
        @verbose     = node[:sidekiq][:verbose]
        @redis_pool_size     = node[:sidekiq][:redis_pool_size]
        @concurrency = opsworks.get_pool_size()
        @logfile     = "/data/helpkit/shared/log/sidekiq_#{count}.log"
        @pidfile     = "/data/helpkit/shared/pids/sidekiq_#{count}.pid"
        f.write(Erubis::Eruby.new(File.read(sidekiq_in_templ)).result(binding))
      end
    end
  end

  def self.get_pool(node)
    utility_name = node[:opsworks][:instance][:hostname]

    # This change is specifically for staging environment to overcome the memory issue.
    common_pool_worker_count = node[:opsworks][:instance][:layers].count > 1 ? 4 : 7

    #queue names
    default                  = ["default"]
    rabbitmq                 = ["rabbitmq_publish","merge_contacts","account_info_to_dynamo","data_export","broadcast_note","link_tickets","reset_associations","manual_publish"]
    contacts_merge           = ["merge_contacts", "rabbitmq_publish","account_info_to_dynamo","account_creation_fixtures", "product_feedback"]
    supervisor               = ["supervisor"]
    free_supervisor          = ["free_supervisor,supervisor"]
    trial_supervisor         = ["trial_supervisor,supervisor"]
    premium_supervisor       = ["premium_supervisor,supervisor"]
    facebook                 = ["premium_facebook","facebook","trial_facebook","custom_twitter","fb_split_tickets","dev_notification_worker","upload_avatar_worker","facebook_delta","twitter_gnip_worker","twitter_replay_worker"]
    facebook_comments        = ["facebook_comments","fb_split_tickets","dev_notification_worker","upload_avatar_worker","facebook_delta","flush_portal_solution_cache"]
    twitter                  = ["custom_twitter","premium_facebook","facebook","trial_facebook","fb_split_tickets","dev_notification_worker","upload_avatar_worker","facebook_delta","twitter_replay_worker","twitter_gnip_worker"]
    paid_sla                 = ["sla","premium_sla"]
    free_sla                 = ["free_sla","sla","trial_sla"]
    trial_sla                = ["trial_sla","sla","free_sla"]
    premium_sla              = ["premium_sla","sla","free_sla","trial_sla"]
    reports_one              = ["report_export_queue","scheduled_reports","update_tickets_company","reports_no_activity","parallel_report_exports","update_tickets_company_id","agent_destroy_cleanup", "freshid_events", "freshid_account_details_update", "launch_party_actions", "freshid_agents_migration", "run_rake_task", "freshid_v2_events", "freshid_v2_agents_migration", "freshid_account_details_update_v2", "widget_upload_config"]
    reports_two              = ["scheduled_reports","reports_no_activity", "update_tickets_company","report_export_queue","parallel_report_exports","update_users_company_id","agent_destroy_cleanup","update_tickets_company_id"]
    reset                    = ["reset_group", "reset_responder","modify_ticket_status","remove_secondary_companies","contacts_sync","contacts_sync_free","contacts_sync_paid","contacts_sync_trial"]
    search_one               = ["es_index_queue","count_es_queue","es_alias_queue","es_v2_queue","tag_uses_destroy","solution_binarize_sync","parallel_report_exports","update_all_callbacks","esv2_count_index","kbase_content_spam_checker","forum_content_spam_checker"]
    search_two               = ["es_alias_queue","new_es_index","es_index_queue","tag_uses_destroy","es_v2_queue","solution_binarize_sync","parallel_report_exports","count_es_queue","update_all_callbacks","esv2_count_index"]
    freshfone_one            = ["freshfone_notifications","freshfone_node","freshfone_trial_worker"]
    freshfone_two            = ["freshfone_node","freshfone_notifications","freshfone_trial_worker"]
    solution                 = ['solution_language_change', 'deactivate_monitorship', 'export_agents', 'clear_moderation_records', 'empty_moderation_trash', 'flush_portal_solution_cache', 'generate_sitemap', 'clear_sitemap', 'remove_encrypted_fields', 'freshid_retry_worker', 'anonymous_account_cleanup', 'sandbox_cleanup', 'update_sandbox_subscription', 'kbase_article_versions_worker', 'kbase_article_versions_migration_worker', 'kbase_article_versions_reset_rating', 'articles_export_queue', 'kbase_approval_notification_worker', 'delete_solution_meta_worker', 'solution_article_central_publish', 'solution_templates_migration_worker', 'update_article_platform_mapping_worker', 'search_analytics_article_reindex']
    archive_splitter         = ["archive_ticket_splitter"]
    archive_splitter_delete  = ["archive_delete_ticket","archive_modify_ticket_association","archive_build_create_ticket"]
    archive_build            = ["archive_build_create_ticket","archive_modify_ticket_association","archive_delete_ticket","archive_delete_ticket_dependencies"]
    archive_modify           = ["archive_modify_ticket_association","archive_delete_ticket","archive_build_create_ticket"]
    archive_delete           = ["archive_delete_ticket","archive_modify_ticket_association","archive_build_create_ticket","archive_delete_ticket_dependencies"]
    archive_delete_ticket_dependencies = ["archive_delete_ticket_dependencies","archive_delete_ticket","archive_modify_ticket_association","archive_build_create_ticket"]
    ebay                     = ["ebay_user_worker","ebay_worker","ebay_message_worker"]
    observer                 = ["ticket_observer","update_ticket_states","merge_tickets","merge_tickets_attachments","send_and_set_observer","thank_you_note"]
    service_task_observer    = ["service_task_observer"]
    ticket_states            = ["update_ticket_states","ticket_observer","merge_tickets","merge_tickets_attachments"]
    merge_tickets            = ["merge_tickets","merge_tickets_attachments","update_ticket_states","ticket_observer"]
    gamification             = ["reset_gamification_score","bulk_scenario"]
    password_expiry          = ["password_expiry","chargebee_invoice","sla_on_status_change", "reset_internal_group", "update_ticket_filter","reset_internal_agent","s3_retry_worker","learn_spam_message"]
    github                   = ["github","bulk_scenario","sla_on_status_change","reset_internal_agent","update_ticket_filter", "reset_internal_group"]
    bulk_scenario            = ["bulk_scenario"]
    select_all_tickets       = ["select_all_tickets","select_all_batcher","email_notification_spam_queue","sandbox_sync","account_info_to_dynamo","email_delivery"]
    select_all_batcher       = ["select_all_batcher","email_notification_spam_queue","learn_spam_message","s3_retry_worker","sandbox_sync","spam_data_migration"]
    premium_sla_reminder     = ["premium_sla_reminders","sla_reminders"]
    sla_reminder             = ["sla_reminders","premium_sla_reminders"]
    trial_sla_reminders      = ["trial_sla_reminders","premium_sla_reminders","sla_reminders"]
    free_sla_reminders       = ["free_sla_reminders","premium_sla_reminders","sla_reminders"]
    webhook_worker           = ["webhook_v1_worker","cti","delete_account","bulk_child_tkt_creation"]
    webhook_throttler        = ["webhook_v1_worker","cti","templates_cleanup"]
    bulk_ticket              = ["bulk_ticket_actions","bulk_ticket_reply","clear_tickets","code_console_execution","data_enrichment"]
    language                 = ["update_user_language","clear_tickets","chargebee_add_subscription","partners_event_queue","detect_user_language","forum_content_spam_checker","collaboration_publish"]
    integrations             = ["integrations","chargebee_invoice","clear_tickets","marketplace_apps","installed_app_business_rule","cloud_elements_delete","salesforce_integrated_resource_migrate","cloud_elements_logger_email"]
    dispatcher               = ["active_dispatcher","premium_dispatcher","dispatcher","trial_dispatcher","free_dispatcher"]
    premium_dispatcher       = ["premium_dispatcher","active_dispatcher","dispatcher","trial_dispatcher","free_dispatcher"]
    service_task_dispatcher  = ["service_task_dispatcher"]
    quality_management_system = ['quality_management_system']
    privilege_modification   = ['privilege_modification']
    api_webhook_rule         = ["api_webhook_rule"]
    plan_change              = ["plan_change","pod_route_update","helpdesk_ticket_body_queue","modify_ticket_status","plan_change_workerv2","activation_worker"]
    contact_import           = ["contact_import","company_import","helpdesk_note_body_queue","data_export","broadcast_note","link_tickets","reset_associations","modify_ticket_status"]
    riak_s3_ticket           = ["helpdesk_ticket_body_queue","helpdesk_update_ticket_body_queue","helpdesk_note_body_queue","helpdesk_update_note_body_queue","update_sentiment","update_notes_sentiment"]
    riak_s3_note             = ["helpdesk_note_body_queue","helpdesk_update_note_body_queue","helpdesk_ticket_body_queue","helpdesk_update_ticket_body_queue","notify_broadcast_message"]
    reports_three            = ["contact_export","company_export","data_export","livechat_worker","broadcast_note","link_tickets","reset_associations"]
    delete_spam_tickets      = ["delete_spam_tickets","data_export","broadcast_note","link_tickets","reset_associations"]
    ticket_export            = ["tickets_export_queue","long_running_ticket_export","premium_ticket_export","scheduled_ticket_export","activity_export","scheduled_ticket_export_config","scheduled_ticket_export"]
    long_running_ticket_export = ["long_running_ticket_export","premium_ticket_export","tickets_export_queue","scheduled_ticket_export"]
    premium_ticket_export    = ["premium_ticket_export","long_running_ticket_export","tickets_export_queue"]
    suspended_accounts_deletion = ["suspended_accounts_deletion","cti"]
    round_robin              = ["round_robin_capping","assign_tickets_to_agents","sbrr_assignment","sbrr_user_toggle","sbrr_group_toggle","sbrr_config_agent_group","sbrr_config_user_skill", "sbrr_config_skill"]
    round_robin_sbr          = ["sbrr_assignment","sbrr_user_toggle","sbrr_group_toggle","sbrr_config_agent_group","sbrr_config_user_skill","round_robin_capping","sbrr_config_skill","assign_tickets_to_agents", "skill_import"]
    trial_account_jobs       = ["trial_account_jobs","free_account_jobs","active_account_jobs","premium_account_jobs"]
    free_account_jobs        = ["free_account_jobs","trial_account_jobs","active_account_jobs","premium_account_jobs","sendgrid_domain_updates"]
    paid_account_jobs        = ["active_account_jobs","premium_account_jobs","trial_account_jobs"]
    premium_account_jobs     = ["premium_account_jobs","active_account_jobs","trial_account_jobs"]
    mail_box_jobs            = ["mailbox_jobs"]
    bulk_api                 = ["bulk_api_jobs"]
    dkim                     = ["dkim_verifier","dkim_general"]
    manual_publish           = ["manual_publish","rabbitmq_publish","merge_contacts","account_info_to_dynamo","data_export","broadcast_note","link_tickets","reset_associations"]
    remaining                = ["manual_publish","facebook_comments","es_v2_queue","email_delivery"]
    moved_queues             = ["rabbitmq_publish", "freshfone_notifications", "premium_account_jobs", "sendgrid_domain_updates", "contacts_sync_paid", "flush_portal_solution_cache", "twitter_replay_worker", "es_alias_queue", "update_sentiment", "integrations", "trial_account_jobs", "contacts_sync", "new_es_index", "clear_moderation_records", "bulk_ticket_actions", "bulk_child_tkt_creation", "account_info_to_dynamo", "chargebee_invoice", "update_ticket_states", "twitter", "es_index_queue", "sbrr_config_agent_group", "sbrr_assignment", "scheduled_reports_cleanup", "active_dispatcher", "solution_binarize_sync", "trial_dispatcher", "sla_on_status_change", "update_tickets_company", "account_creation_fixtures", "activation_worker", "twitter_gnip_worker", "github", "free_dispatcher", "fb_split_tickets", "password_expiry", "ebay_worker", "free_account_jobs", "premium_ticket_export", "helpdesk_ticket_body_queue", "activity_export", "custom_twitter", "scheduled_ticket_export_config", "livechat_worker", "premium_dispatcher", "round_robin_capping", "facebook_delta", "data_enrichment", "plan_change_workerv2", "tag_uses_destroy", "merge_tickets", "upload_avatar_worker", "scheduled_reports", "reset_gamification_score", "spam_data_migration", "helpdesk_update_ticket_body_queue", "contact_export", "modify_ticket_status", "update_notes_sentiment", "ebay_message_worker", "broadcast_note", "kbase_content_spam_checker", "update_ticket_filter", "clear_sitemap", "helpdesk_update_note_body_queue", "contact_import", "report_export_queue", "select_all_tickets", "freshfone_trial_worker", "premium_facebook", "link_tickets", "clear_tickets", "collaboration_publish", "update_user_language", "code_console_execution", "trial_sla_reminders", "cloud_elements_logger_email", "product_feedback", "export_agents", "tickets_export_queue", "dev_notification_worker", "generate_sitemap", "natero_worker", "solution_language_change", "detect_user_language", "reports_no_activity", "cloud_elements_delete", "parallel_report_exports", "contacts_sync_trial", "sbrr_group_toggle", "update_users_company_id", "send_signup_activation_mail", "dispatcher", "update_tickets_company_id", "facebook", "webhook_v1_worker", "dkim_verifier", "s3_retry_worker", "ticket_observer", "company_import", "select_all_batcher", "trial_sla", "freshfone_node", "salesforce_integrated_resource_migrate", "plan_change", "reopen_tickets", "long_running_ticket_export", "premium_sla_reminders", "free_sla_reminders", "ebay_user_worker", "free_sla", "delayed_jobs", "assign_tickets_to_agents", "dkim_general", "free_supervisor", "notify_broadcast_message", "supervisor", "pod_route_update", "merge_tickets_attachments", "api_webhook_rule", "deactivate_monitorship", "merge_contacts", "agent_destroy_cleanup", "sandbox_sync", "reset_internal_group", "suspended_accounts_deletion", "trial_supervisor", "data_export", "premium_supervisor", "bulk_scenario", "reset_associations", "helpdesk_note_body_queue", "sbrr_config_skill", "esv2_count_index", "sla_reminders", "reset_internal_agent", "empty_moderation_trash", "populate_account_setup", "marketplace_apps", "chargebee_add_subscription", "trial_facebook", "reset_group", "bulk_ticket_reply", "remove_secondary_companies", "send_and_set_observer", "cti", "premium_sla", "sbrr_config_user_skill", "sbrr_user_toggle", "installed_app_business_rule", "learn_spam_message", "skill_import", "scheduled_ticket_export", "active_account_jobs", "contacts_sync_free", "email_notification_spam_queue", "update_all_callbacks", "delete_account", "count_es_queue", "templates_cleanup", "forum_content_spam_checker", "partners_event_queue", "sla", "delete_spam_tickets", "reset_responder"]
    freshcaller              = ["freshcaller_migration_worker", "freshcaller_account_delete", 'freshcaller_update_agents']
    cron_jobs                = ['cron_contacts_sync', 'cron_google_contacts_sync', 'cron_resque_watcher_check_load', 'cron_scheduler_sla', 'cron_scheduler_sla_reminder', 'cron_scheduler_supervisor', 'cron_forum_moderation_create_tables', 'cron_forum_moderation_drop_tables', 'cron_facebook_dm', 'cron_spam_digest_mailer', 'cron_twitter_custom_stream', 'cron_populate_spam_watcher_limits', 'cron_billing_info_update', 'cron_requeue_central_publish', 'cron_rollback_trail_subscriptions_data', 'cron_sidekiq_dead_set_mailer', 'cron_redis_maintenance', 'cron_ebay_daily_api_report_intimate', 'cron_reports_build_no_activity', 'cron_scheduled_task', 'cron_sitemap_generate', 'cron_traffic_switch_fetch_accounts', 'cron_long_running_queries_check', 'cron_gnip_stream_maintenance', 'cron_gnip_stream_replay', 'cron_social_create_dynamodb_tables', 'cron_social_delete_dynamodb_tables', 'cron_sqs_monitor', 'cron_account_spam_cleanup', 'cron_attachment_user_draft_cleanup', 'cron_delayedjobs_watcher', 'cron_failed_helpkit_feeds', 'cron_log_cloud_elements_sync', 'cron_freshfone', 'cron_meta_data_check', 'cron_enable_omniroute_for_new_accounts', 'cron_archive_automation']
    roles                    = ["update_agents_roles"]
    all_set                  = [dispatcher,observer,ticket_states,paid_account_jobs,premium_account_jobs,trial_account_jobs,free_account_jobs,default,rabbitmq,contacts_merge,supervisor,free_supervisor,trial_supervisor,premium_supervisor,facebook,facebook_comments,twitter,paid_sla,free_sla,trial_sla,premium_sla,reports_one,reports_two,reset,search_one,search_two,freshfone_one,freshfone_two,solution,ebay,merge_tickets,gamification,password_expiry,github,bulk_scenario,select_all_tickets,select_all_batcher,premium_sla_reminder,sla_reminder,trial_sla_reminders,free_sla_reminders,webhook_worker,webhook_throttler,bulk_ticket,language,integrations,api_webhook_rule,plan_change,contact_import,riak_s3_ticket,riak_s3_note,reports_three,delete_spam_tickets,ticket_export,long_running_ticket_export ,premium_ticket_export,suspended_accounts_deletion,round_robin,round_robin_sbr,mail_box_jobs,bulk_api,dkim,manual_publish, cron_jobs, roles]

    dedicated_realtime = ["realtime"]
    dedicated_bulk = ["bulk_scheduled", "exports", "occasional"]
    dedicated_email = ["email", "mailbox_jobs"]
    dedicated_occasional = ["scheduled", "occasional"]
    dedicated_central = ["central_realtime"]
    dedicated_scheduled = ["scheduled", "maintainence"]
    dedicated_common = ["realtime", "scheduled", "occasional", "email", "mailbox_jobs", "bulk_api", "maintainence", "external", "trial", "spam", "exports", "bulk_scheduled"]



    all = []
    all_set.each do |arr|
      arr.each do |queue|
        all << queue
      end
    end

    realtime                 = ["realtime"]
    scheduled                = ["scheduled"]
    maintainence             = ["maintainence"]
    free                     = ["free"]
    email                    = ["email"]
    trial                    = ["trial"]
    spam                     = ["spam"]
    export                   = ["exports"]
    bulk_scheduled           = ["bulk_scheduled"]
    central_realtime         = ["central_realtime"]
    mailbox_jobs             = ["mailbox_jobs"]
    bulk_api                 = ["bulk_api"]
    # falcon_occasional        = ["falcon_occasional"]
    gamification             = ["gamification"]
    community                = ["community"]
    subscriptions            = ["subscriptions"]
    hard_delete              = ["hard_delete"]
    cron_webhook             = ['cron_webhook']

    # new classification
    occasional               = ['occasional']
    frequent                 = ['frequent']
    maintenance              = ['maintenance']
    archive                  = ['archive_account_tickets', 'archive_ticket', 'manual_publish', 'delayed_central_publish', 'es_v2_queue', 'central_realtime']
    external                 = ['external']
    long_running             = ['long_running']

    all_sidekiq_jobs         = cron_jobs + ["default", "rabbitmq_publish", "merge_contacts", "account_info_to_dynamo",
  "broadcast_note", "link_tickets", "reset_associations", "manual_publish", "supervisor", "free_supervisor,supervisor",
  "trial_supervisor,supervisor", "premium_supervisor,supervisor", "premium_facebook", "facebook", "trial_facebook",
  "custom_twitter", "fb_split_tickets", "dev_notification_worker",
  "upload_avatar_worker", "facebook_delta", "twitter_gnip_worker", "twitter_replay_worker", "facebook_comments",
  "flush_portal_solution_cache", "sla", "premium_sla", "free_sla", "trial_sla", "report_export_queue", "scheduled_reports",
  "update_tickets_company", "reports_no_activity", "parallel_report_exports", "update_tickets_company_id",
  "agent_destroy_cleanup", "update_users_company_id", "reset_group", "reset_responder", "reset_archive_tickets", "modify_ticket_status",
  "remove_secondary_companies", "contacts_sync", "contacts_sync_free", "contacts_sync_paid", "contacts_sync_trial",
  "es_index_queue", "count_es_queue", "es_alias_queue", "es_v2_queue", "tag_uses_destroy", "solution_binarize_sync",
  "update_all_callbacks", "esv2_count_index", "kbase_content_spam_checker", "new_es_index",
  "natero_worker", "reopen_tickets", "solution_language_change", "deactivate_monitorship", "export_agents", "clear_moderation_records", "empty_moderation_trash", "generate_sitemap",
  "clear_sitemap", "archive_ticket_splitter", "archive_delete_ticket", "archive_modify_ticket_association",
  "archive_build_create_ticket", "archive_delete_ticket_dependencies", "ebay_user_worker", "ebay_worker",
  "ebay_message_worker", "ticket_observer", "service_task_observer", "update_ticket_states", "merge_tickets", "merge_tickets_attachments",
  "reset_gamification_score", "bulk_scenario", "password_expiry", "chargebee_invoice", "sla_on_status_change",
  "reset_internal_group", "update_ticket_filter", "reset_internal_agent", "s3_retry_worker", "learn_spam_message",
  "github", "select_all_tickets", "select_all_batcher", "email_notification_spam_queue", "sendgrid_domain_updates",
  "sandbox_sync", "premium_sla_reminders", "sla_reminders", "trial_sla_reminders", "free_sla_reminders", "webhook_v1_worker",
  "cti", "delete_account", "bulk_child_tkt_creation", "templates_cleanup", "bulk_ticket_actions", "bulk_ticket_reply",
  "clear_tickets", "code_console_execution", "update_user_language", "chargebee_add_subscription", "partners_event_queue",
  "detect_user_language", "integrations", "marketplace_apps", "installed_app_business_rule", "cloud_elements_delete",
  "salesforce_integrated_resource_migrate", "cloud_elements_logger_email", "active_dispatcher", "premium_dispatcher", "service_task_dispatcher",
  "dispatcher", "trial_dispatcher", "free_dispatcher", "api_webhook_rule", "plan_change", "pod_route_update",
  "helpdesk_ticket_body_queue", "plan_change_workerv2", "activation_worker", "contact_import", "company_import",
  "helpdesk_note_body_queue", "helpdesk_update_ticket_body_queue", "helpdesk_update_note_body_queue", "update_sentiment",
  "update_notes_sentiment", "notify_broadcast_message", "contact_export", "company_export", "livechat_worker",
  "delete_spam_tickets", "tickets_export_queue", "long_running_ticket_export", "premium_ticket_export",
  "suspended_accounts_deletion", "round_robin_capping", "assign_tickets_to_agents", "sbrr_assignment", "sbrr_user_toggle",
  "sbrr_group_toggle", "sbrr_config_agent_group", "sbrr_config_user_skill", "trial_account_jobs", "free_account_jobs",
  "active_account_jobs", "premium_account_jobs", "mailbox_jobs", "bulk_api_jobs", "dkim_verifier", "dkim_general","sbrr_config_skill",
  "skill_import","forum_content_spam_checker", "scheduled_ticket_export_config","scheduled_ticket_export",
  "account_creation_fixtures","email_delivery","collaboration_publish","activity_export","send_and_set_observer",
  "realtime","scheduled","occasional","maintainence","external","free","email","trial","spam", "product_feedback",
  "block_account","signup_restricted_domain_validation","send_activation_reminder_mail",
  "ner_worker","email_service_provider", "freshid_events", "freshid_account_details_update",
  'freshid_v2_events', 'freshid_account_details_update_v2',
  'freshid_v2_agents_migration', "launch_party_actions", "data_enrichment", "central_publish", "cre_central_publish",
  "free_ticket_central_publish", "trial_ticket_central_publish", "active_ticket_central_publish", "suspended_ticket_central_publish",
  "free_note_central_publish", "trial_note_central_publish", "active_note_central_publish", "suspended_note_central_publish",
  "channel_framework_command", "ml_solutions_training","bot_cleanup","calculate_sla", "delayed_central_publish", "update_taggables_queue",
  "customer_note_body_queue", "toggle_agent_from_all_roundrobin_groups","add_agent_to_round_robin","marketo_queue",
  "subscription_events_queue","restore_spam_tickets","jira_acc_config_updates","report_post_worker","merge_topics",
  "spam_digest_mailer","forum_post_spam_marker","forum_ban_user","nullify_deleted_custom_field_data", "track_customer_in_freshsales", "gamification", "community", "subscription","subscriptions", "freshid_agents_migration",
  "contact_delete_forever","create_sandbox_account","delete_sandbox","sandbox_data_to_file","sandbox_file_to_data",
  "clone", "inline_image_shredder", "deactivate_product_widgets", "deactivate_filter_widgets", "user_central_publish", "update_time_zone","sandbox_diff", "sandbox_merge", "run_rake_task","check_bot_training","update_segment_filter",
  "register_freshconnect", "undo_send", "unlink_tickets", "primary_language_change", "send_domain_changed_mail", "default_data_population", 'freshops_service', 'twitter_reply',
  "widget_upload_config", "bot_email_reply", "bot_email_ml_feedback", 'migration', 'company_central_publish', "ticket_field_central_publish",
  "scheduler_post_message", "scheduler_cancel_message", "delete_archive_ticket", "freshcaller_account_delete", "remove_encrypted_fields", "cancel_account", 'ocr_agent_sync', 'ocr_task_sync',
  'custom_translations_upload_queue', 'audit_log_export', "http_request", "simple_outreach_import", "surveys_central_publish", "freshvisual_configs", "anonymous_account_cleanup",
  'contact_field_central_publish', 'company_field_central_publish', 'freshid_retry_worker', "model_destroy", "freshcaller_account_central_publish", "freshchat_account_central_publish", "email_service_account_details_destroy", 'freshcaller_update_agents',
  "sandbox_cleanup", "thank_you_note", "update_sandbox_subscription", 'gateway_facebook_page', "archive_account_tickets_channel_queue", "archive_tickets_channel_queue", "ticket_properties_suggester", "update_agents_roles", "custom_translations_update_survey_status", 'kbase_article_versions_worker', 'kbase_article_versions_migration_worker',
  'kbase_article_versions_reset_rating', 'articles_export_queue', 'rts_account_create', 'image_meta_data_delete', 'kbase_approval_notification_worker', 'delete_solution_meta_worker', 'ticket_field_job', 'update_url_in_sandbox', 'fdadmin_freshid_migration', 'vault_account_update', 'vault_data_cleanup', 'update_user_privilege',
  'archive_account_tickets', 'freshcaller_subscription_events_queue', 'freshchat_subscription_events_queue', 'solution_article_central_publish', 'central_realtime', 'frequent', 'maintenance', 'twitter_survey', 'bitmap_callbacks', 'facebook_survey', 'quality_management_system', 'solution_templates_migration_worker', 'update_article_platform_mapping_worker', 'update_agent_status_availability',
  'marketplace_app_billing', 'privilege_modification', 'search_analytics_article_reindex', 'touchstone_account_update'
]

    # sidekiq queues in falcon alone
    # falcon_all_sidekiq      =  ["scheduler_post_message", "scheduler_cancel_message", "delete_archive_ticket", "freshcaller_account_delete"]

    _SLA_POOL                 = [[paid_sla,2],[free_sla,2],[trial_sla,1],[premium_sla,1]]
    _SUPERVISOR_POOL          = [[supervisor,3,3],[free_supervisor,2,3],[trial_supervisor,1,3],[premium_supervisor,1,3]]
    _SOCIAL_POOL              = [[facebook,1],[twitter,1],[rabbitmq,1],[contacts_merge,1],[reset,1],[plan_change,1]]
    _NORMAL_POOL              = [[default,1]]
    #Don't change the order for reports_pool as logs being temprarily pushed to sumologic based on workers
    _REPORTS_POOL             = [[reports_one,2],[reports_two,2],[reset,1],[freshfone_one,1]]
    _PUBLISH_POOL             = [[rabbitmq,2],[contact_import,1],[reports_three,2,2],[delete_spam_tickets,1,1]]
    _SEARCH_POOL              = [[search_one,2],[search_two,2],[ebay,1]]
    _FRESHFONE_POOL           = [[freshfone_one,2],[freshfone_two,1],[search_one,1],[solution,1],[ticket_export,1]]
    _ARCHIVE_POOL             = [[archive_splitter_delete,1],[archive_build,1],[archive_modify,1],[archive_delete,1],[archive_delete_ticket_dependencies,1],[archive_splitter,1,1]]
    _OBSERVER_POOL            = [[observer,4],[ticket_states,2]]
    _TICKETS_POOL             = [[ticket_states,3],[observer,2],[merge_tickets,1]]
    _GAMIFICATION_POOL        = [[gamification,1],[search_one,1],[password_expiry,1],[github,1],[bulk_scenario,1],[api_webhook_rule,1],[language,1]]
    _SELECT_ALL_POOL          = [[select_all_tickets,1],[select_all_batcher,1],[premium_sla_reminder,1],[sla_reminder,1],[trial_sla_reminders,1],[free_sla_reminders,1]]
    _INTEGRATIONS_POOL        = [[integrations,2],[bulk_ticket,3],[api_webhook_rule,1]]
    _DISPATCHER_POOL          = [[dispatcher,2],[premium_dispatcher,3],[api_webhook_rule,1]]
    _WEBHOOK_POOL             = [[webhook_worker,2],[webhook_throttler,2],[suspended_accounts_deletion,1,1],[round_robin,1]]
    _RIAK_POOL                = [[riak_s3_ticket,3],[riak_s3_note,3]]
    _EXPORT_POOL              = [[ticket_export,3],[long_running_ticket_export,2],[premium_ticket_export,1]]
    _DELAYEDJOB_POOL          = [[trial_account_jobs,2],[free_account_jobs,2],[premium_account_jobs,2]]
    _PAIDJOB_POOL             = [[paid_account_jobs,6]]
    _MAILBOX_POOL             = [[mail_box_jobs,4],[dkim,1]]
    _BULK_API_POOL            = [[bulk_api, 6]]
    _ROUND_ROBIN_POOL         = [[round_robin,3],[round_robin_sbr,3]]
    _MANUAL_PUBLISH_POOL      = [[manual_publish,3],[rabbitmq,3]]
    _ALL_POOL                 = [[all,6]]
    _COMMON_POOL              = [[all_sidekiq_jobs, common_pool_worker_count]]
    _MOVED_POOL               = [[moved_queues,1], [remaining,5]]
    # FALCON_COMMON_POOL       = [[falcon_all_sidekiq, common_pool_worker_count]]
    _FRESHCALLER_POOL         = [[freshcaller,6]]

    _REALTIME_POOL            = [[realtime,6]]
    _SCHEDULED_POOL           = [[scheduled,6]]
    _MAINTAINENCE_POOL        = [[maintainence,6]]
    _FREE_POOL                = [[free,6]]
    _EMAIL_POOL               = [[email,6]]
    _TRIAL_POOL               = [[trial,6]]
    _SPAM_POOL                = [[spam,6]]
    _EXPORT_POOL              = [[export,6]]
    _CRON_POOL                = [[cron_webhook, 6]]
    # Increasing it to 8 because in attributes/default the number of workers has been changed to
    # the number of CPU's in the machine. But here it is just hardcoded.
    # This has to be made dynamic based on the type of machine.
    _BULK_SCHEDULED_POOL      = [[bulk_scheduled,8]]
    _CENTRAL_REALTIME_POOL    = [[central_realtime, 6]]
    _MAILBOXJOB_POOL          = [[mailbox_jobs, 6]]
    _BULK_API_POOL            = [[bulk_api, 6]]
    _GAMIFICATION_POOL        = [[gamification, 6]]
    _COMMUNITY_POOL           = [[community, 6]]
    _SUBSCRIPTION_POOL        = [[subscriptions, 6]]
    _HARD_DELETE_POOL         = [[hard_delete, 6]]

    _DEDICATED_REALTIME_POOL     = [[dedicated_realtime,6]]
    _DEDICATED_BULK_POOL         = [[dedicated_bulk,6]]
    _DEDICATED_EMAIL_POOL        = [[dedicated_email,6]]
    _DEDICATED_OCCASIONAL_POOL   = [[dedicated_occasional,6]]
    _DEDICATED_CENTRAL_POOL      = [[dedicated_central,6]]
    _DEDICATED_SCHEDULED_POOL    = [[dedicated_scheduled,6]]
    _DEDICATED_COMMON_POOL       = [[dedicated_common,6]]

    # new classification
    occasional_pool          = [[occasional, 6]]
    frequent_pool            = [[frequent, 6]]
    maintenance_pool         = [[maintenance, 4]]
    archive_pool             = [[archive, 6]]
    external_pool            = [[external, 6]]
    longrunning_pool         = [[long_running, 6]]

    case
    when utility_name.include?(SLA_SIDEKIQ)
      _SLA_POOL
    when utility_name.include?(SUPERVISOR_SIDEKIQ)
      _SUPERVISOR_POOL
    when utility_name.include?(SOCIAL_SIDEKIQ)
      _SOCIAL_POOL
    when utility_name.include?(REPORTS_SIDEKIQ)
      _REPORTS_POOL
    when utility_name.include?(SEARCH_SIDEKIQ)
      _SEARCH_POOL
    when utility_name.include?(FRESHFONE_SIDEKIQ)
      _FRESHFONE_POOL
    when utility_name.include?(OBSERVER_SIDEKIQ)
      _OBSERVER_POOL
    when utility_name.include?(TICKETS_SIDEKIQ)
      _TICKETS_POOL
    when utility_name.include?(GAMIFICATION_SIDEKIQ)
      _GAMIFICATION_POOL
    when utility_name.include?(SUBSCRIPTION_SIDEKIQ)
      _SUBSCRIPTION_POOL
    when utility_name.include?(COMMUNITY_SIDEKIQ)
      _COMMUNITY_POOL
    when utility_name.include?(HARD_DELETE_SIDEKIQ)
      _HARD_DELETE_POOL
    when utility_name.include?(PUBLISH_SIDEKIQ)
      _PUBLISH_POOL
    when utility_name.include?(SELECT_ALL_SIDEKIQ)
      _SELECT_ALL_POOL
    when utility_name.include?(INTEGRATIONS_SIDEKIQ)
      _INTEGRATIONS_POOL
    when utility_name.include?(DISPATCHER_SIDEKIQ)
      _DISPATCHER_POOL
    when utility_name.include?(WEBHOOK_SIDEKIQ)
      _WEBHOOK_POOL
    when utility_name.include?(RIAK_SIDEKIQ)
      _RIAK_POOL
    when utility_name.include?(EXPORT_SIDEKIQ)
      _EXPORT_POOL
    when utility_name.include?(DELAYEDJOB_SIDEKIQ)
      _DELAYEDJOB_POOL
    when utility_name.include?(PAIDJOB_SIDEKIQ)
      _PAIDJOB_POOL
    when utility_name.include?(MAILBOXJOB_SIDEKIQ)
      _MAILBOX_POOL
    when utility_name.include?(BULK_API_SIDEKIQ)
      _BULK_API_POOL
    when utility_name.include?(ROUND_ROBIN_SIDEKIQ)
      _ROUND_ROBIN_POOL
    when utility_name.include?(MANUAL_PUBLISH_SIDEKIQ)
      _MANUAL_PUBLISH_POOL
    when utility_name.include?(ALL_SIDEKIQ)
      _ALL_POOL
    when utility_name.include?(NORMAL_SIDEKIQ)
      _NORMAL_POOL
    when utility_name.include?(CENTRAL_REALTIME_SIDEKIQ)
      _CENTRAL_REALTIME_POOL
    when utility_name.include?(REALTIME_SIDEKIQ)
      _REALTIME_POOL
    when BULKSCHEDULED_SIDEKIQ.any? { |pool_name| utility_name.include?(pool_name) }
      _BULK_SCHEDULED_POOL
    when utility_name.include?(SCHEDULED_SIDEKIQ)
      _SCHEDULED_POOL
    # when utility_name.include?(FALCON_OCCASIONAL)
    #   FALCON_OCCASIONAL_POOL
    when utility_name.include?(MAINTAINENCE_SIDEKIQ)
      _MAINTAINENCE_POOL
    when utility_name.include?(FREE_SIDEKIQ)
      _FREE_POOL
    when utility_name.include?(EMAIL_SIDEKIQ)
      _EMAIL_POOL
    when utility_name.include?(TRIAL_SIDEKIQ)
      _TRIAL_POOL
    when utility_name.include?(SPAM_SIDEKIQ)
      _SPAM_POOL
    when utility_name.include?(MOVED_SIDEKIQ)
      _MOVED_POOL
    when utility_name.include?(MAILBOXJOB_SIDEKIQ)
      _MAILBOXJOB_POOL
    when utility_name.include?(CRON_SIDEKIQ)
      _CRON_POOL
    when utility_name.include?(DEDICATED_REALTIME)
      _DEDICATED_REALTIME_POOL
    when utility_name.include?(DEDICATED_BULK)
      _DEDICATED_BULK_POOL
    when utility_name.include?(DEDICATED_EMAIL)
      _DEDICATED_EMAIL_POOL
    when utility_name.include?(DEDICATED_OCCASIONAL)
      _DEDICATED_OCCASIONAL_POOL
    when utility_name.include?(DEDICATED_CENTRAL)
      _DEDICATED_CENTRAL_POOL
    when utility_name.include?(DEDICATED_SCHEDULED)
      _DEDICATED_SCHEDULED_POOL
    when utility_name.include?(DEDICATED_COMMON)
      _DEDICATED_COMMON_POOL
    when utility_name.include?(FRESHCALLER_SIDEKIQ)
      _FRESHCALLER_POOL
    # new classification
    when utility_name.include?(OCCASIONAL_SIDEKIQ)
      occasional_pool
    when utility_name.include?(FREQUENT_SIDEKIQ)
      frequent_pool
    when utility_name.include?(MAINTENANCE_SIDEKIQ)
      maintenance_pool
    when utility_name.include?(ARCHIVE_SIDEKIQ)
      archive_pool
    when utility_name.include?(EXTERNAL_SIDEKIQ)
      external_pool
    when utility_name.include?(LONG_RUNNING)
      longrunning_pool
    # when utility_name.include?(FALCON_COMMON_SIDEKIQ)
    #   FALCON_COMMON_POOL
    when utility_name.include?(COMMON_SIDEKIQ)
      _COMMON_POOL
    else
      _COMMON_POOL
    end
  end

  def self.queue_priorities(pool_name)
    queue_priorities = []
    pool_name.each do |queue_def|
      queue_def[1].times {|name| queue_priorities << queue_def[0]}
    end
    queue_priorities
  end
end

class SidekiqConfigStandard

  SLA_SIDEKIQ              = "sidekiq-sla-"
  SUPERVISOR_SIDEKIQ       = "sidekiq-supervisor-"
  SOCIAL_SIDEKIQ           = "sidekiq-social-"
  SEARCH_SIDEKIQ           = "sidekiq-search-"
  REPORTS_SIDEKIQ          = "sidekiq-reports-"
  DELAYEDJOB_SIDEKIQ       = "sidekiq-delayed-jobs-"
  FRESHFONE_SIDEKIQ        = "sidekiq-freshfone-"
  COMMON_SIDEKIQ           = "sidekiq-common-"
  MISC_SIDEKIQ             = "sidekiq-misc-"
  REALTIME_SIDEKIQ         = "sidekiq-realtime-"
  SCHEDULED_SIDEKIQ        = "sidekiq-scheduled-"
  MAINTAINENCE_SIDEKIQ     = "sidekiq-maintainence-"
  FREE_SIDEKIQ             = "sidekiq-free-"
  EMAIL_SIDEKIQ            = "sidekiq-email-"
  TRIAL_SIDEKIQ            = "sidekiq-trial-"
  SPAM_SIDEKIQ             = "sidekiq-spam-"
  ARCHIVE_SIDEKIQ          = "sidekiq-archive-"
  MAILBOXJOBS_SIDEKIQ      = "sidekiq-mailbox-jobs-"
  BULK_API_SIDEKIQ         = "sidekiq-bulk-api-"
  EXPORT_SIDEKIQ           = "sidekiq-exports-"
  CRON_SIDEKIQ             = 'sidekiq-cron-'
  DATAEXPORT_SIDEKIQ       = "sidekiq-dataexport-"
  CENTRAL_REALTIME_SIDEKIQ = "sidekiq-central-realtime-"

  # new classifications
  OCCASIONAL_SIDEKIQ       = 'sidekiq-occasional-'.freeze
  FREQUENT_SIDEKIQ         = 'sidekiq-frequent-'.freeze
  MAINTENANCE_SIDEKIQ      = 'sidekiq-maintenance-'.freeze
  ARCHIVE_SIDEKIQ          = 'sidekiq-archive-'.freeze
  EXTERNAL_SIDEKIQ         = 'sidekiq-external-'.freeze
  LONG_RUNNING             = 'sidekiq-longrunning-'.freeze


  def self.get_pool(node)
    utility_name = node[:opsworks][:instance][:hostname]

    # This change is specifically for staging environment to overcome the memory issue.
    common_pool_worker_count = node[:opsworks][:instance][:layers].count > 1 ? 4 : 7

    reports_one              = ["update_tickets_company","update_tickets_company_id","ticket_observer","update_users_company_id","reports_no_activity","report_export_queue","reset_group", "reset_responder","rabbitmq_publish","merge_contacts","sla","sla_scheduler","github","chargebee_invoice","api_webhook_rule","merge_tickets","merge_tickets_attachments","natero_worker","marketplace_apps","agent_destroy_cleanup","contact_import","company_import","premium_ticket_export","twitter_gnip_worker","twitter_replay_worker","parallel_report_exports","solution_binarize_sync","data_export","count_es_queue","sendgrid_domain_updates","bulk_child_tkt_creation","email_delivery","send_and_set_observer", "freshid_events", "freshid_account_details_update", "launch_party_actions", "ml_solutions_training", "bot_cleanup", "freshid_agents_migration", "contact_delete_forever", "inline_image_shredder", "run_rake_task","check_bot_training", "update_segment_filter", "primary_language_change", 'freshops_service', "widget_upload_config", "freshid_v2_events", "freshid_v2_agents_migration", "freshid_account_details_update_v2"]
    ebay                     = ["webhook_v1_worker","ebay_user_worker","ebay_worker","ebay_message_worker","clear_tickets","delete_spam_tickets","suspended_accounts_deletion","solution_binarize_sync","count_es_queue","email_notification_spam_queue","sendgrid_domain_updates","sla_on_status_change","delete_account","sbrr_config_skill", "forum_content_spam_checker","account_creation_fixtures","activity_export", "product_feedback", "block_account","signup_restricted_domain_validation","send_activation_reminder_mail","ner_worker","email_service_provider"]
    reset                    = ["update_ticket_states","ticket_observer","reset_group", "reset_responder","update_tickets_company","reports_no_activity","sla","sla_scheduler","update_users_company_id","rabbitmq_publish","bulk_scenario","merge_contacts","github","update_tickets_company_id","clear_tickets","api_webhook_rule","merge_tickets","merge_tickets_attachments","natero_worker","marketplace_apps","agent_destroy_cleanup","webhook_v1_worker","tickets_export_queue","parallel_report_exports","solution_binarize_sync","data_export","count_es_queue","empty_moderation_trash","remove_secondary_companies","contacts_sync","contacts_sync_free","contacts_sync_paid","contacts_sync_trial","templates_cleanup","cloud_elements_logger_email","collaboration_publish", "deactivate_product_widgets", "deactivate_filter_widgets","update_time_zone"]
    #search_one               = ["es_index_queue","es_alias_queue","update_ticket_states","solution_language_change","export_agents","deactivate_monitorship","supervisor","premium_supervisor","trial_supervisor" ,"free_supervisor","plan_change","bulk_scenario","clear_tickets","api_webhook_rule","merge_tickets","merge_tickets_attachments", "premium_facebook","facebook","trial_facebook","twitter","trial_twitter","custom_twitter","facebook_delta","fb_split_tickets","freshfone_trial_worker","natero_worker","marketplace_apps","agent_destroy_cleanup","scheduled_reports","parallel_report_exports","solution_binarize_sync","installed_app_business_rule","esv2_count_index"]
    search_one               = ["es_index_queue","es_alias_queue","update_ticket_states","solution_language_change","export_agents","deactivate_monitorship","supervisor","premium_supervisor","trial_supervisor" ,"free_supervisor","plan_change","bulk_scenario","clear_tickets","api_webhook_rule","merge_tickets","merge_tickets_attachments", "premium_facebook","facebook","trial_facebook","custom_twitter","facebook_delta","fb_split_tickets","natero_worker","marketplace_apps","agent_destroy_cleanup","scheduled_reports","parallel_report_exports","solution_binarize_sync","installed_app_business_rule","esv2_count_index","code_console_execution","reopen_tickets","salesforce_integrated_resource_migrate","scheduled_ticket_export","account_creation_fixtures", "data_enrichment", "central_publish", "user_central_publish", "free_ticket_central_publish", "trial_ticket_central_publish", "active_ticket_central_publish", "suspended_ticket_central_publish", "calculate_sla", "update_taggables_queue","company_central_publish", "ticket_field_central_publish", 'contact_field_central_publish', 'company_field_central_publish', 'freshcaller_account_central_publish', 'freshchat_account_central_publish']
    solution_one = ['solution_language_change', 'export_agents', 'es_index_queue', 'es_alias_queue', 'premium_supervisor', 'trial_supervisor', 'deactivate_monitorship', 'free_supervisor', 'supervisor', 'reset_gamification_score', 'plan_change', 'chargebee_invoice', 'clear_tickets', 'merge_tickets', 'merge_tickets_attachments', 'contact_export', 'company_export', 'data_export', 'scheduled_reports', 'livechat_worker', 'solution_binarize_sync', 'clear_moderation_records', 'generate_sitemap', 'clear_sitemap', 'cloud_elements_delete', 'kbase_content_spam_checker', 'activation_worker', 'scheduled_ticket_export_config', 'skill_import', 'mixpanel_queue', 'sandbox_cleanup', 'update_sandbox_subscription', 'kbase_article_versions_worker', 'kbase_article_versions_migration_worker', 'kbase_article_versions_reset_rating', 'articles_export_queue', 'solution_templates_migration_worker']
    #solution                 = ["update_all_callbacks","solution_language_change","export_agents","update_ticket_states","es_index_queue","es_alias_queue","facebook","dev_notification_worker","upload_avatar_worker","trial_supervisor","premium_supervisor","free_supervisor","supervisor","password_expiry","reset_gamification_score","plan_change","premium_dispatcher","dispatcher","trial_dispatcher","free_dispatcher","active_dispatcher","merge_tickets","merge_tickets_attachments","pod_route_update","long_running_ticket_export","chargebee_add_subscription","partners_event_queue","account_info_to_dynamo","webhook_v1_worker"]
    solution                 = ["update_all_callbacks","solution_language_change","export_agents","update_ticket_states","es_index_queue","es_alias_queue","facebook","dev_notification_worker","upload_avatar_worker","trial_supervisor","premium_supervisor","free_supervisor","supervisor","password_expiry","reset_gamification_score","plan_change","premium_dispatcher","dispatcher","trial_dispatcher","free_dispatcher","active_dispatcher","merge_tickets","merge_tickets_attachments","pod_route_update","long_running_ticket_export","chargebee_add_subscription","partners_event_queue","account_info_to_dynamo","webhook_v1_worker","notify_broadcast_message","detect_user_language","forum_content_spam_checker", "remove_encrypted_fields", "freshid_retry_worker"]
    batch_select_and_sla     = ["facebook","trial_facebook","custom_twitter","select_all_tickets", "select_all_batcher","premium_sla_reminders","sla_reminders","trial_sla_reminders","free_sla_reminders","report_export_queue","facebook","dev_notification_worker","upload_avatar_worker","bulk_ticket_actions","bulk_ticket_reply","integrations","update_user_language","premium_dispatcher","dispatcher","trial_dispatcher","free_dispatcher","active_dispatcher","merge_tickets","merge_tickets_attachments","helpdesk_ticket_body_queue","helpdesk_update_ticket_body_queue","helpdesk_note_body_queue","helpdesk_update_note_body_queue","archive_delete_ticket_dependencies","es_v2_queue","tag_uses_destroy","account_info_to_dynamo","webhook_v1_worker","cti","broadcast_note","link_tickets","reset_associations","reset_internal_group", "reset_internal_agent", "update_ticket_filter", "unlink_tickets", 'migration']

    sla                      = ["premium_sla","free_sla","trial_sla","round_robin_capping","assign_tickets_to_agents","modify_ticket_status","update_sentiment","update_notes_sentiment","s3_retry_worker","customer_note_body_queue","flush_portal_solution_cache","learn_spam_message","sandbox_sync","sbrr_assignment","sbrr_user_toggle","sbrr_group_toggle","sbrr_config_agent_group","sbrr_config_user_skill","dkim_verifier","dkim_general","plan_change_workerv2","manual_publish", "delayed_central_publish", "channel_framework_command","create_sandbox_account","delete_sandbox","sandbox_file_to_data","sandbox_data_to_file",  "clone", "sandbox_diff", "sandbox_merge", 'ocr_agent_sync', 'ocr_task_sync']

    ### Don't add anything to this ###
    freshfone_new            = ["freshfone_notifications","freshfone_trial_worker", "freshcaller_migration_worker"]
    freshfone_node           = ["freshfone_node"]
    ### Don't add anything to this ###

    misc_sidekiq             = ["toggle_agent_from_all_roundrobin_groups","add_agent_to_round_robin","marketo_queue","subscription_events_queue","restore_spam_tickets","jira_acc_config_updates","report_post_worker","merge_topics","spam_digest_mailer","forum_post_spam_marker","forum_ban_user","nullify_deleted_custom_field_data","gamification_user_score","gamification_ticket_score","gamification_topic_quests","gamification_ticket_quests","gamification_solution_quests","gamification_post_quests", "track_customer_in_freshsales", "thank_you_note", "ticket_properties_suggester", "image_meta_data_delete"]

    trial_account_jobs       = ["trial_account_jobs","active_account_jobs","premium_account_jobs","free_account_jobs"]
    free_account_jobs        = ["free_account_jobs","active_account_jobs","premium_account_jobs","trial_account_jobs"]
    active_account_jobs      = ["active_account_jobs","premium_account_jobs","trial_account_jobs","mailbox_jobs"]
    premium_account_jobs     = ["premium_account_jobs","active_account_jobs","trial_account_jobs","mailbox_jobs"]
    # archive_splitter         = ["archive_ticket_splitter","archive_delete_ticket","archive_modify_ticket_association","archive_build_create_ticket"]
    # archive_build            = ["archive_build_create_ticket","archive_modify_ticket_association","archive_delete_ticket"]
    # archive_modify           = ["archive_modify_ticket_association","archive_delete_ticket","archive_build_create_ticket"]
    # archive_delete           = ["archive_delete_ticket","archive_modify_ticket_association","archive_build_create_ticket"]
    cron_jobs                = ['cron_contacts_sync', 'cron_google_contacts_sync', 'cron_resque_watcher_check_load', 'cron_scheduler_sla', 'cron_scheduler_sla_reminder', 'cron_scheduler_supervisor', 'cron_forum_moderation_create_tables', 'cron_forum_moderation_drop_tables', 'cron_facebook_dm', 'cron_spam_digest_mailer', 'cron_twitter_custom_stream', 'cron_populate_spam_watcher_limits', 'cron_billing_info_update', 'cron_requeue_central_publish', 'cron_rollback_trail_subscriptions_data', 'cron_sidekiq_dead_set_mailer', 'cron_redis_maintenance', 'cron_ebay_daily_api_report_intimate', 'cron_reports_build_no_activity', 'cron_scheduled_task', 'cron_sitemap_generate', 'cron_traffic_switch_fetch_accounts', 'cron_long_running_queries_check', 'cron_gnip_stream_maintenance', 'cron_gnip_stream_replay', 'cron_social_create_dynamodb_tables', 'cron_social_delete_dynamodb_tables', 'cron_sqs_monitor', 'cron_account_spam_cleanup', 'cron_attachment_user_draft_cleanup', 'cron_delayedjobs_watcher', 'cron_failed_helpkit_feeds', 'cron_log_cloud_elements_sync', 'cron_freshfone', 'cron_meta_data_check', 'cron_enable_omniroute_for_new_accounts', 'cron_archive_automation']

all_sidekiq_jobs =  cron_jobs + [
      "default", "rabbitmq_publish", "merge_contacts", "account_info_to_dynamo", "broadcast_note",
      "link_tickets", "reset_associations", "manual_publish", "supervisor", "free_supervisor,supervisor", "trial_supervisor,supervisor",
      "premium_supervisor,supervisor", "premium_facebook", "facebook", "trial_facebook",
      "custom_twitter", "fb_split_tickets", "dev_notification_worker", "upload_avatar_worker", "facebook_delta", "twitter_gnip_worker",
      "twitter_replay_worker", "facebook_comments", "flush_portal_solution_cache", "sla", "premium_sla", "free_sla", "trial_sla",
      "report_export_queue", "scheduled_reports", "update_tickets_company", "reports_no_activity", "parallel_report_exports","email_service_provider",
      "update_tickets_company_id", "agent_destroy_cleanup", "update_users_company_id", "reset_group", "reset_responder", "reset_archive_tickets",
      "modify_ticket_status", "remove_secondary_companies", "contacts_sync", "contacts_sync_free", "contacts_sync_paid",
      "contacts_sync_trial", "es_index_queue", "count_es_queue", "es_alias_queue", "es_v2_queue", "tag_uses_destroy",
      "solution_binarize_sync", "update_all_callbacks", "esv2_count_index", "kbase_content_spam_checker", "new_es_index",
      "natero_worker", "reopen_tickets", "solution_language_change", "deactivate_monitorship", "export_agents", "clear_moderation_records", "empty_moderation_trash", "generate_sitemap", "clear_sitemap",
      "archive_ticket_splitter", "archive_delete_ticket", "archive_modify_ticket_association", "archive_build_create_ticket",
      "archive_delete_ticket_dependencies", "ebay_user_worker", "ebay_worker", "ebay_message_worker", "ticket_observer", "service_task_observer",
      "update_ticket_states", "merge_tickets", "merge_tickets_attachments", "reset_gamification_score", "bulk_scenario", "password_expiry",
      "chargebee_invoice", "sla_on_status_change", "reset_internal_group", "update_ticket_filter", "reset_internal_agent", "s3_retry_worker",
      "learn_spam_message", "github", "select_all_tickets", "select_all_batcher", "email_notification_spam_queue", "sendgrid_domain_updates",
      "sandbox_sync", "premium_sla_reminders", "sla_reminders", "trial_sla_reminders", "free_sla_reminders", "webhook_v1_worker", "cti",
      "delete_account", "bulk_child_tkt_creation", "templates_cleanup", "bulk_ticket_actions", "bulk_ticket_reply", "clear_tickets",
      "code_console_execution", "update_user_language", "chargebee_add_subscription", "partners_event_queue", "detect_user_language",
      "integrations", "marketplace_apps", "installed_app_business_rule", "cloud_elements_delete", "salesforce_integrated_resource_migrate",
      "cloud_elements_logger_email", "active_dispatcher", "premium_dispatcher", "dispatcher", "trial_dispatcher", "free_dispatcher", "service_task_dispatcher",
      "api_webhook_rule", "plan_change", "pod_route_update", "helpdesk_ticket_body_queue", "plan_change_workerv2", "activation_worker",
      "contact_import", "company_import", "helpdesk_note_body_queue", "helpdesk_update_ticket_body_queue", "helpdesk_update_note_body_queue",
      "update_sentiment", "update_notes_sentiment", "notify_broadcast_message", "contact_export", "company_export", "livechat_worker",
      "delete_spam_tickets", "tickets_export_queue", "long_running_ticket_export", "premium_ticket_export", "suspended_accounts_deletion",
      "round_robin_capping", "assign_tickets_to_agents", "sbrr_assignment", "sbrr_user_toggle", "sbrr_group_toggle", "sbrr_config_agent_group",
      "sbrr_config_user_skill", "trial_account_jobs", "free_account_jobs", "active_account_jobs", "premium_account_jobs", "mailbox_jobs",
      "dkim_verifier", "dkim_general", "sbrr_config_skill","forum_content_spam_checker","scheduled_ticket_export_config", "bulk_api_jobs",
      "scheduled_ticket_export","skill_import","mixpanel_queue","account_creation_fixtures","email_delivery","collaboration_publish",
      "activity_export","send_and_set_observer","realtime","scheduled","occasional","maintainence","external","free","email","trial","spam",
      "product_feedback","block_account","signup_restricted_domain_validation","freshcaller_migration_worker","send_activation_reminder_mail",
      "ner_worker", "freshid_events", "freshid_account_details_update", "email_service_account_details_destroy",
      "free_note_central_publish", "trial_note_central_publish", "active_note_central_publish", "suspended_note_central_publish", "cre_central_publish",
      "launch_party_actions", "data_enrichment", "central_publish", "user_central_publish", "free_ticket_central_publish", "trial_ticket_central_publish",
      "active_ticket_central_publish", "suspended_ticket_central_publish", "channel_framework_command", "ml_solutions_training","bot_cleanup", "calculate_sla",
      "delayed_central_publish", "update_taggables_queue", "customer_note_body_queue", "toggle_agent_from_all_roundrobin_groups","add_agent_to_round_robin",
      "marketo_queue", "subscription_events_queue", "restore_spam_tickets","jira_acc_config_updates", "report_post_worker","merge_topics","spam_digest_mailer",
      "forum_post_spam_marker","forum_ban_user","nullify_deleted_custom_field_data","gamification_user_score",
      "gamification_ticket_score", "gamification_topic_quests","gamification_ticket_quests","gamification_solution_quests",
      "gamification_post_quests", "track_customer_in_freshsales", "freshid_agents_migration","contact_delete_forever","create_sandbox_account",
      "delete_sandbox","sandbox_data_to_file","sandbox_file_to_data", "clone", "inline_image_shredder", "deactivate_product_widgets",
      "deactivate_filter_widgets","update_time_zone","sandbox_diff", "sandbox_merge", "run_rake_task","check_bot_training","update_segment_filter",
      "register_freshconnect", "undo_send", "unlink_tickets", "primary_language_change", "send_domain_changed_mail", "default_data_population", 'freshops_service', 'twitter_reply',
      "widget_upload_config", "bot_email_reply", "bot_email_ml_feedback", 'migration',
      "company_central_publish", "ticket_field_central_publish", "scheduler_post_message", "scheduler_cancel_message", "delete_archive_ticket","freshcaller_account_delete", 'freshcaller_update_agents', "remove_encrypted_fields", "cancel_account", 'ocr_agent_sync', 'ocr_task_sync',
      'custom_translations_upload_queue', 'audit_log_export', "http_request", "simple_outreach_import", "surveys_central_publish", "freshvisual_configs", "anonymous_account_cleanup",
      'contact_field_central_publish', 'company_field_central_publish', 'freshid_v2_events', 'freshid_account_details_update_v2', 'freshid_v2_agents_migration', 'freshid_retry_worker',
      "model_destroy", "freshcaller_account_central_publish", "freshchat_account_central_publish", "sandbox_cleanup" , "thank_you_note", "update_sandbox_subscription", 'gateway_facebook_page',
      "archive_account_tickets_channel_queue", "archive_tickets_channel_queue", "ticket_properties_suggester", "update_agents_roles", "custom_translations_update_survey_status", 'kbase_article_versions_worker', 'kbase_article_versions_migration_worker',
      'kbase_article_versions_reset_rating', 'articles_export_queue', 'rts_account_create', 'kbase_approval_notification_worker', 'delete_solution_meta_worker', 'ticket_field_job', 'update_url_in_sandbox', 'fdadmin_freshid_migration', 'vault_account_update', 'vault_data_cleanup', 'update_user_privilege',
      'archive_account_tickets', 'freshcaller_subscription_events_queue', 'freshchat_subscription_events_queue', 'solution_article_central_publish', 'central_realtime', 'frequent', 'maintenance', 'twitter_survey', 'bitmap_callbacks', 'facebook_survey', 'quality_management_system', 'solution_templates_migration_worker', 'update_article_platform_mapping_worker', 'update_agent_status_availability',
      'marketplace_app_billing', 'privilege_modification', 'search_analytics_article_reindex', 'touchstone_account_update'
    ]

    #falcon common sidekiq

    # falcon_all_sidekiq = ["scheduler_post_message", "scheduler_cancel_message", "delete_archive_ticket","freshcaller_account_delete","toggle_agent_from_all_roundrobin_groups","add_agent_to_round_robin","marketoQueue","salesforceQueue","events_queue","metrics_data","restore_spam_tickets_worker",
    #     "jira_updates","check_for_spam","report_post","merge_topics","spam_digest_mailer","bulk_spam","ban_user","nullify_deleted_custom_field_data",
    #     "gamification_user_score","gamification_ticket_score","gamification_topic_quests","gamification_ticket_quests","gamification_solution_quests","gamification_post_quests"]
    realtime                 = ["realtime"]
    scheduled                = ["scheduled"]
    maintainence             = ["maintainence"]
    free                     = ["free"]
    email                    = ["email"]
    trial                    = ["trial"]
    spam                     = ["spam"]
    mailbox                  = ["mailbox_jobs"]
    export                   = ["exports"]
    cron_webhook             = ['cron_webhook']
    realtime                 = ["realtime"]
    bulk_scheduled           = ["bulk_scheduled"]
    central_realtime         = ["central_realtime"]
    mailbox_jobs             = ["mailbox_jobs"]
    bulk_api                 = ["bulk_api"]
    gamification             = ["gamification"]
    community                = ["community"]
    subscriptions            = ["subscriptions"]
    hard_delete              = ["hard_delete"]

    # new classification
    occasional               = ['occasional']
    frequent                 = ['frequent']
    maintenance              = ['maintenance']
    archive                  = ['archive_account_tickets', 'archive_ticket', 'manual_publish', 'delayed_central_publish', 'es_v2_queue', 'central_realtime']
    external                 = ['external']
    long_running             = ['long_running']

    # SUPERVISOR_POOL        = [[rabbitmq,1],[#paid_sla,1],[premium_free_supervisor,1][trial_supervisor,1][search_one,1][solution_one,1]]
    _SEARCH_POOL              = [[search_one,1],[solution_one,1],[reports_one,1],[solution,1],[reset,1],[ebay,1],[batch_select_and_sla,1],[sla,1]]
    _DELAYEDJOB_POOL          = [[trial_account_jobs,1],[free_account_jobs,1],[active_account_jobs,1],[premium_account_jobs,1]]
    _FRESHFONE_POOL           = [[freshfone_new,2],[freshfone_node,1]]

    _COMMON_POOL              = [[all_sidekiq_jobs, common_pool_worker_count]]
    # FALCON_COMMON_POOL       = [[falcon_all_sidekiq, common_pool_worker_count]]

    _REALTIME_POOL            = [[realtime,6]]
    _SCHEDULED_POOL           = [[scheduled,6]]
    _MAINTAINENCE_POOL        = [[maintainence,6]]
    _FREE_POOL                = [[free,6]]
    _EMAIL_POOL               = [[email,6]]
    _TRIAL_POOL               = [[trial,6]]
    _SPAM_POOL                = [[spam,6]]
    _MAILBOX_POOL             = [[mailbox,6]]
    _BULK_API_POOL            = [[bulk_api, 6]]
    _EXPORT_POOL              = [[export, 6]]
    _MISC_POOL                = [[misc_sidekiq,6]]
    _CRON_POOL                = [[cron_webhook, 6]]
    _CENTRAL_REALTIME_POOL    = [[central_realtime, 6]]

    # new classification
    occasional_pool          = [[occasional, 6]]
    frequent_pool            = [[frequent, 6]]
    maintenance_pool         = [[maintenance, 4]]
    archive_pool             = [[archive, 6]]
    external_pool            = [[external, 6]]
    longrunning_pool         = [[long_running, 6]]

    case
    when utility_name.include?(SEARCH_SIDEKIQ)
      _SEARCH_POOL
    when utility_name.include?(FRESHFONE_SIDEKIQ)
      _FRESHFONE_POOL
    when utility_name.include?(SUPERVISOR_SIDEKIQ)
      _SUPERVISOR_POOL
    when utility_name.include?(SOCIAL_SIDEKIQ)
      _SOCIAL_POOL
    when utility_name.include?(REPORTS_SIDEKIQ)
      _REPORTS_POOL
    when utility_name.include?(DELAYEDJOB_SIDEKIQ)
      _DELAYEDJOB_POOL
    when utility_name.include?(REALTIME_SIDEKIQ)
      _REALTIME_POOL
    when utility_name.include?(SCHEDULED_SIDEKIQ)
      _SCHEDULED_POOL
    when utility_name.include?(MAINTAINENCE_SIDEKIQ)
      _MAINTAINENCE_POOL
    when utility_name.include?(FREE_SIDEKIQ)
      _FREE_POOL
    when utility_name.include?(EMAIL_SIDEKIQ)
      _EMAIL_POOL
    when utility_name.include?(TRIAL_SIDEKIQ)
      _TRIAL_POOL
    when utility_name.include?(SPAM_SIDEKIQ)
      _SPAM_POOL
    when utility_name.include?(MAILBOXJOBS_SIDEKIQ)
      _MAILBOX_POOL
    when utility_name.include?(BULK_API_SIDEKIQ)
      _BULK_API_POOL
    when utility_name.include?(EXPORT_SIDEKIQ)
      _EXPORT_POOL
    when utility_name.include?(MISC_SIDEKIQ)
      _MISC_POOL
    when utility_name.include?(CENTRAL_REALTIME_SIDEKIQ)
      _CENTRAL_REALTIME_POOL
    when utility_name.include?(CRON_SIDEKIQ)
      _CRON_POOL
    # new classification
    when utility_name.include?(OCCASIONAL_SIDEKIQ)
      occasional_pool
    when utility_name.include?(FREQUENT_SIDEKIQ)
      frequent_pool
    when utility_name.include?(MAINTENANCE_SIDEKIQ)
      maintenance_pool
    when utility_name.include?(ARCHIVE_SIDEKIQ)
      archive_pool
    when utility_name.include?(EXTERNAL_SIDEKIQ)
      external_pool
    when utility_name.include?(LONG_RUNNING)
      longrunning_pool
    # when utility_name.include?(FALCON_COMMON_SIDEKIQ)
    #   FALCON_COMMON_POOL
    when utility_name.include?(COMMON_SIDEKIQ)
      _COMMON_POOL
    else
      _COMMON_POOL
    end
  end

  def self.setup(node, opsworks, options, sidekiq_in_templ, sidekiq_monitrc_templ)
    require 'enumerator'

    puts "Setting up standard sidekiq"

    pool = get_pool(node)
    queues = queue_priorities(pool)

    puts "Queues in this instance: #{queues.inspect}"

    worker_count = queues.size

    # bin script
    # /usr/bin/sidekiq_wrapper is part of docker itself

    # monit
    File.open("/etc/monit.d/bg/sidekiq_helpkit.monitrc", 'w') do |f|
      @app_name     = "helpkit"
      @workers      = worker_count
      @environment = node[:opsworks][:environment]
      @memory_limit = node[:sidekiq][:memory] || 3072 # MB
      f.write(Erubis::Eruby.new(File.read(sidekiq_monitrc_templ)).result(binding))
    end

    # yml files
    worker_count.times do |count|
      out = File.join(options[:outdir], "sidekiq_client_#{count}.yml")
      File.open(out, 'w') do |f|
        @environment = node[:opsworks][:environment]
        @queues      = queues[count]
        @verbose     = node[:sidekiq][:verbose]
        @concurrency = opsworks.get_pool_size()
        @logfile     = "/data/helpkit/shared/log/sidekiq_#{count}.log"
        @pidfile     = "/data/helpkit/shared/pids/sidekiq_#{count}.pid"
        f.write(Erubis::Eruby.new(File.read(sidekiq_in_templ)).result(binding))
      end
    end
  end

  def self.queue_priorities(pool_name)
    queue_priorities = []
    pool_name.each do |queue_def|
      queue_def[1].times {|name| queue_priorities << queue_def[0]}
    end
    queue_priorities
  end
end
