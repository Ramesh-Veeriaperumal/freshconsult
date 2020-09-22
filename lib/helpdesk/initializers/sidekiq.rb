config = YAML::load_file(File.join(Rails.root, 'config', 'sidekiq.yml'))[Rails.env]
sidekiq_config = YAML::load_file(File.join(Rails.root, 'config', 'sidekiq_client.yml'))[Rails.env]

MAX_DEAD_SET_SIZE = 50_000

SIDEKIQ_CLASSIFICATION = YAML::load_file(File.join(Rails.root, 'config', 'sidekiq_classification.yml'))

SIDEKIQ_CLASSIFICATION_MAPPING = SIDEKIQ_CLASSIFICATION[:classification].inject({}) do |t_h, queue|
  queue.last.each do |q|
    t_h[q] = queue.first
  end
  t_h
end

SIDEKIQ_CLASSIFICATION_MAPPING_NEW = SIDEKIQ_CLASSIFICATION[:new_classification].inject({}) do |t_h, queue|
  queue.last.each do |q|
    t_h[q] = queue.first
  end
  t_h
end

REDIS_CONFIG_KEYS = ['host', 'port', 'password', 'namespace'].freeze

redis_config = config.slice(*REDIS_CONFIG_KEYS).merge(tcp_keepalive: config['keepalive'], network_timeout: sidekiq_config['timeout'])

DUP_SIDEKIQ_CONFIG = redis_config.dup

pool_size = sidekiq_config[:redis_pool_size] || sidekiq_config[:concurrency]

sidekiq_client_redis_pool_size = (pool_size / 2).to_i
sidekiq_client_redis_pool_size = pool_size if sidekiq_client_redis_pool_size.zero?

poll_interval = config['scheduled_poll_interval']
Sidekiq.default_worker_options = { backtrace: 10 }
Sidekiq.options[:dead_max_jobs] = config['dead_max_jobs'] || MAX_DEAD_SET_SIZE
Sidekiq.configure_client do |config|
  config.redis = redis_config.merge({:size => sidekiq_client_redis_pool_size})
  config.client_middleware do |chain|
    chain.add Middleware::Sidekiq::Client::RouteORDrop
    chain.add Middleware::Sidekiq::Client::BelongsToAccount, :ignore => [
      "FreshopsToolsWorker",
      "Social::TwitterReplyStreamWorker",
      "RabbitmqWorker",
      "ManualPublishWorker",
      "Tickets::SelectAll::BatcherWorker",
      "Sidekiq::Batch::Callback",
      "Freshfone::CallQueueWorker",
      "Freshfone::AcwWorker",
      "Freshfone::TranscriptAttachmentWorker",
      "Freshfone::CallTimeoutWorker",
      "Freshcaller::AccountDeleteWorker",
      "Ecommerce::EbayWorker",
      "Ecommerce::EbayUserWorker",
      "PasswordExpiryWorker",
      "WebhookV1Worker",
      "SendSignupActivationMail",
      "DevNotificationWorker",
      "PodDnsUpdate",
      "SearchV2::Manager::DisableSearch",
      "Gamification::ProcessTicketQuests",
      "AccountCleanup::DeleteSpamTicketsCleanup",
      "AccountCleanup::SuspendedAccountsWorker",
      "Social::Gnip::ReplayWorker",
      "Social::Gnip::RuleWorker",
      "Reports::ScheduledReports",
      "Reports::BuildNoActivity",
      "Social::PremiumFacebookWorker",
      "Reports::NoActivityWorker",
      "DelayedJobs::ActiveAccountJob",
      "DelayedJobs::FreeAccountJob",
      "DelayedJobs::TrialAccountJob",
      "DelayedJobs::PremiumAccountJob",
      "DelayedJobs::DelayedAccountJob",
      "DkimRecordVerificationWorker",
      "DkimSwitchCategoryWorker",
      "DelayedJobs::MailboxJob",
      "Email::S3RetryWorker",
      'Email::AccountDetailsDestroyWorker',
      "Tickets::Schedule",
      "Tickets::Dump",
      "BlockAccount",
      "Freshid::ProcessEvents",
      "CRMApp::Freshsales::Signup",
      "CRMApp::Freshsales::AdminUpdate",
      "CRMApp::Freshsales::TrackSubscription",
      "Admin::Sandbox::CreateAccountWorker",
      'Admin::CloneWorker',
      'Freshid::AccountDetailsUpdate',
      'MigrationWorker',
      'DataExportCleanup',
      'Freshid::V2::ProcessEvents',
      'Freshid::V2::AccountDetailsUpdate',
      'FreshidRetryWorker',
      'Admin::Sandbox::CleanupWorker',
      'Admin::Sandbox::UpdateSubscriptionWorker',
      'AccountCleanup::RebalancedAccountDeleteWorker',
      'Search::Analytics::AccountCleanupWorker',
      'Search::Analytics::TicketsCleanupWorker',
      'AccountCreation::PrecreateAccounts'
    ]
    chain.add Middleware::Sidekiq::Client::SetCurrentUser, :required_classes => [
      "AccountCreation::PopulateSeedData",
      "Tickets::BulkScenario",
      "Tickets::BulkTicketActions",
      "Tickets::BulkTicketReply",
      "Tickets::ClearTickets::EmptySpam",
      "Tickets::ClearTickets::EmptyTrash",
      "MergeTickets",
      "Export::ContactWorker",
      "Export::CompanyWorker",
      "Tickets::Export::TicketsExport",
      "Tickets::Export::LongRunningTicketsExport",
      "Tickets::Export::PremiumTicketsExport",
      "Reports::ScheduledReports",
      "Reports::Export",
      "LivechatWorker",
      "Tickets::LinkTickets",
      "Tickets::UnlinkTickets",
      "BroadcastMessages::NotifyBroadcastMessages",
      "BroadcastMessages::NotifyAgent",
      "Import::SkillWorker",
      "ExportAgents",
      "CollabNotificationWorker",
      "ProductFeedbackWorker",
      "Freshid::ProcessEvents",
      "Community::MergeTopicsWorker",
      "Admin::Sandbox::FileToDataWorker",
      "Admin::Sandbox::DataToFileWorker",
      "Admin::Sandbox::DiffWorker",
      'Admin::Sandbox::MergeWorker',
      'Tickets::UndoSendWorker',
      'Freshid::V2::ProcessEvents',
      "Roles::UpdateAgentsRoles",
      'AuditLogExport',
      "Solution::ApprovalNotificationWorker",
      'Freshcaller::UpdateAgentsWorker',
      'QualityManagementSystem::PerformQmsOperationsWorker',
      'UpdateAgentStatusAvailability',
      'PrivilegesModificationWorker'
    ]
  end
end

require 'prometheus_exporter/instrumentation' if ENV['ENABLE_PROMETHEUS'] == '1'
Sidekiq.configure_server do |config|
  # ActiveRecord::Base.logger = Logger.new(STDOUT)
  # Sidekiq::Logging.logger = ActiveRecord::Base.logger
  # Sidekiq::Logging.logger.level = ActiveRecord::Base.logger.level

  # Sidekiq takes care of ideal redis pool size based on concurrency
  # It will be `concurrency + 5` unless, we override
  config.redis = redis_config
  config.super_fetch!
  config.reliable_scheduler!
  config.average_scheduled_poll_interval = poll_interval if poll_interval.present?
  config.error_handlers << proc { |ex, ctx_hash|
    begin
      log_tags = (ctx_hash.try(:[], 'message_uuid') || [])
      log_tags << ctx_hash['jid']
    rescue StandardError => e
      log_tags = []
    end
    Rails.logger.tagged(log_tags) do
      Rails.logger.error "Sidekiq worker failed: #{ex.message}, context: #{ctx_hash.inspect}"
      Rails.logger.error "Sidekiq worker Backtrace: #{ex.backtrace.join(', ')}"
    end
  }
  config.on :startup do
    PrometheusExporter::Instrumentation::Process.start type: 'sidekiq' if ENV['ENABLE_PROMETHEUS'] == '1'
  end
  #https://forums.aws.amazon.com/thread.jspa?messageID=290781#290781
  #Making AWS as thread safe
  AWS.eager_autoload!
  config.server_middleware do |chain|
    chain.add PrometheusExporter::Instrumentation::Sidekiq if ENV['ENABLE_PROMETHEUS'] == '1'
    chain.add Middleware::Sidekiq::Server::JobDetailsLogger
    chain.add Middleware::Sidekiq::Server::UnsetThread
    chain.add Middleware::Sidekiq::Server::RouteORDrop
    chain.add Middleware::Sidekiq::Server::SupressSqlLogs
    chain.add Middleware::Sidekiq::Server::BelongsToAccount, :ignore => [
      "FreshopsToolsWorker",
      "Social::TwitterReplyStreamWorker",
      "RabbitmqWorker",
      "ManualPublishWorker",
      "Tickets::SelectAll::BatcherWorker",
      "Sidekiq::Batch::Callback",
      "Freshfone::CallQueueWorker",
      "Freshfone::AcwWorker",
      "Freshfone::TranscriptAttachmentWorker",
      "Freshfone::CallTimeoutWorker",
      "Freshcaller::AccountDeleteWorker",
      "Ecommerce::EbayWorker",
      "Ecommerce::EbayUserWorker",
      "PasswordExpiryWorker",
      "WebhookV1Worker",
      "SendSignupActivationMail",
      "DevNotificationWorker",
      "PodDnsUpdate",
      "SearchV2::Manager::DisableSearch",
      "Gamification::ProcessTicketQuests",
      "AccountCleanup::DeleteSpamTicketsCleanup",
      "AccountCleanup::SuspendedAccountsWorker",
      "Social::Gnip::ReplayWorker",
      "Social::Gnip::RuleWorker",
      "Reports::ScheduledReports",
      "Reports::BuildNoActivity",
      "Social::PremiumFacebookWorker",
      "Reports::NoActivityWorker",
      "DelayedJobs::ActiveAccountJob",
      "DelayedJobs::FreeAccountJob",
      "DelayedJobs::TrialAccountJob",
      "DelayedJobs::PremiumAccountJob",
      "DelayedJobs::DelayedAccountJob",
      "DkimRecordVerificationWorker",
      "DkimSwitchCategoryWorker",
      "DelayedJobs::MailboxJob",
      "Email::S3RetryWorker",
      'Email::AccountDetailsDestroyWorker',
      "Tickets::Schedule",
      "Tickets::Dump",
      "BlockAccount",
      "Freshid::ProcessEvents",
      "CRMApp::Freshsales::Signup",
      "CRMApp::Freshsales::AdminUpdate",
      "CRMApp::Freshsales::TrackSubscription",
      "Admin::Sandbox::CreateAccountWorker",
      'Admin::CloneWorker',
      'Freshid::AccountDetailsUpdate',
      'MigrationWorker',
      'DataExportCleanup',
      'Freshid::V2::ProcessEvents',
      'Freshid::V2::AccountDetailsUpdate',
      'FreshidRetryWorker',
      'Admin::Sandbox::CleanupWorker',
      'Admin::Sandbox::UpdateSubscriptionWorker',
      'AccountCleanup::RebalancedAccountDeleteWorker',
      'Search::Analytics::AccountCleanupWorker',
      'Search::Analytics::TicketsCleanupWorker',
      'AccountCreation::PrecreateAccounts'
    ]
    chain.add Middleware::Sidekiq::Server::SetCurrentUser, :required_classes => [
      "AccountCreation::PopulateSeedData",
      "Tickets::BulkScenario",
      "Tickets::BulkTicketActions",
      "Tickets::BulkTicketReply",
      "Tickets::ClearTickets::EmptySpam",
      "Tickets::ClearTickets::EmptyTrash",
      "MergeTickets",
      "Export::ContactWorker",
      "Export::CompanyWorker",
      "Tickets::Export::TicketsExport",
      "Tickets::Export::LongRunningTicketsExport",
      "Tickets::Export::PremiumTicketsExport",
      "Reports::Export",
      "LivechatWorker",
      "Tickets::LinkTickets",
      "Tickets::UnlinkTickets",
      "BroadcastMessages::NotifyBroadcastMessages",
      "BroadcastMessages::NotifyAgent",
      "Import::SkillWorker",
      "ExportAgents",
      "CollabNotificationWorker",
      "Community::MergeTopicsWorker",
      "Admin::Sandbox::DataToFileWorker",
      "Admin::Sandbox::FileToDataWorker",
      "Admin::Sandbox::DiffWorker",
      "Admin::Sandbox::MergeWorker",
      'Tickets::UndoSendWorker',
      "Roles::UpdateAgentsRoles",
      'AuditLogExport',
      'Solution::ApprovalNotificationWorker',
      'Freshcaller::UpdateAgentsWorker',
      'QualityManagementSystem::PerformQmsOperationsWorker',
      'UpdateAgentStatusAvailability',
      'PrivilegesModificationWorker'
    ]
    chain.add Server::SidekiqSober, :redis_connection => $redis_others, 
      :priority => ['account_id', 'shard_name'], 
      :required_classes => [
        'Archive::AccountTicketsWorker',
        'Archive::TicketWorker',
        'CentralPublisher::CentralReSyncWorker'
    ]
    chain.add Middleware::Sidekiq::Server::Throttler, :required_classes => ["WebhookV1Worker"]
  end
  config.client_middleware do |chain|
    chain.add PrometheusExporter::Instrumentation::SidekiqClient if ENV['ENABLE_PROMETHEUS_SIDEKIQ_CLIENT'] == '1'
    chain.add Middleware::Sidekiq::Client::RouteORDrop
    chain.add Middleware::Sidekiq::Client::BelongsToAccount, :ignore => [
      "FreshopsToolsWorker",
      "Social::TwitterReplyStreamWorker",
      "RabbitmqWorker",
      "ManualPublishWorker",
      "Tickets::SelectAll::BatcherWorker",
      "Sidekiq::Batch::Callback",
      "Freshfone::CallQueueWorker",
      "Freshfone::AcwWorker",
      "Freshfone::TranscriptAttachmentWorker",
      "Freshfone::CallTimeoutWorker",
      "Freshcaller::AccountDeleteWorker",
      "Ecommerce::EbayWorker",
      "Ecommerce::EbayUserWorker",
      "PasswordExpiryWorker",
      "WebhookV1Worker",
      "SendSignupActivationMail",
      "DevNotificationWorker",
      "PodDnsUpdate",
      "SearchV2::Manager::DisableSearch",
      "Gamification::ProcessTicketQuests",
      "AccountCleanup::DeleteSpamTicketsCleanup",
      "AccountCleanup::SuspendedAccountsWorker",
      "Social::Gnip::ReplayWorker",
      "Social::Gnip::RuleWorker",
      "Reports::ScheduledReports",
      "Reports::BuildNoActivity",
      "Social::PremiumFacebookWorker",
      "Reports::NoActivityWorker",
      "DelayedJobs::ActiveAccountJob",
      "DelayedJobs::FreeAccountJob",
      "DelayedJobs::TrialAccountJob",
      "DelayedJobs::PremiumAccountJob",
      "DelayedJobs::DelayedAccountJob",
      "DkimRecordVerificationWorker",
      "DkimSwitchCategoryWorker",
      "DelayedJobs::MailboxJob",
      "Email::S3RetryWorker",
      'Email::AccountDetailsDestroyWorker',
      "AccountCreation::PopulateSeedData",
      "Tickets::Schedule",
      "Tickets::Dump",
      "BlockAccount",
      "Freshid::ProcessEvents",
      "CRMApp::Freshsales::Signup",
      "CRMApp::Freshsales::AdminUpdate",
      'CRMApp::Freshsales::TrackSubscription',
      'Admin::Sandbox::CreateAccountWorker',
      'Admin::CloneWorker',
      'Freshid::AccountDetailsUpdate',
      'MigrationWorker',
      'DataExportCleanup',
      'Freshid::V2::ProcessEvents',
      'Freshid::V2::AccountDetailsUpdate',
      'FreshidRetryWorker',
      'Admin::Sandbox::CleanupWorker',
      'Admin::Sandbox::UpdateSubscriptionWorker',
      'AccountCleanup::RebalancedAccountDeleteWorker',
      'Search::Analytics::AccountCleanupWorker',
      'Search::Analytics::TicketsCleanupWorker',
      'AccountCreation::PrecreateAccounts'
    ]
    chain.add Middleware::Sidekiq::Client::SetCurrentUser, :required_classes => [
      "Tickets::BulkScenario",
      "Tickets::BulkTicketActions",
      "Tickets::BulkTicketReply",
      "Tickets::ClearTickets::EmptySpam",
      "Tickets::ClearTickets::EmptyTrash",
      "MergeTickets",
      "Export::ContactWorker",
      "Export::CompanyWorker",
      "Tickets::Export::TicketsExport",
      "Tickets::Export::LongRunningTicketsExport",
      "Tickets::Export::PremiumTicketsExport",
      "Reports::Export",
      "LivechatWorker",
      "Tickets::LinkTickets",
      "Tickets::UnlinkTickets",
      "BroadcastMessages::NotifyBroadcastMessages",
      "BroadcastMessages::NotifyAgent",
      "Import::SkillWorker",
      "ExportAgents",
      "CollabNotificationWorker",
      "ProductFeedbackWorker",
      "Community::MergeTopicsWorker",
      "Admin::Sandbox::DataToFileWorker",
      "Admin::Sandbox::FileToDataWorker",
      "Admin::Sandbox::DiffWorker",
      "Admin::Sandbox::MergeWorker",
      'Tickets::UndoSendWorker',
      "Roles::UpdateAgentsRoles",
      'AuditLogExport',
      'Solution::ApprovalNotificationWorker',
      'Freshcaller::UpdateAgentsWorker',
      'UpdateAgentStatusAvailability',
      'PrivilegesModificationWorker'
    ]
  end
end
