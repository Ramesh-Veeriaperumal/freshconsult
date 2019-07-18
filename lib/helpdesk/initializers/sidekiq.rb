config = YAML::load_file(File.join(Rails.root, 'config', 'sidekiq.yml'))[Rails.env]
sidekiq_config = YAML::load_file(File.join(Rails.root, 'config', 'sidekiq_client.yml'))[Rails.env]

SIDEKIQ_CLASSIFICATION = YAML::load_file(File.join(Rails.root, 'config', 'sidekiq_classification.yml'))

SIDEKIQ_CLASSIFICATION_MAPPING = SIDEKIQ_CLASSIFICATION[:classification].inject({}) do |t_h, queue|
  queue.last.each do |q|
    t_h[q] = queue.first
  end
  t_h
end

$sidekiq_datastore = proc { Redis::Namespace.new(config['namespace'], redis: Redis.new(host: config['host'], port: config['port'], tcp_keepalive: config['keepalive'])) }
$sidekiq_redis_pool_size = sidekiq_config[:redis_pool_size] || sidekiq_config[:concurrency]
# setting redis connection pool size of sidekiq client to (concurrency / 2) because of limitations from redis-labs
$sidekiq_client_redis_pool_size = ($sidekiq_redis_pool_size / 2).to_i
$sidekiq_client_redis_pool_size = $sidekiq_redis_pool_size if $sidekiq_client_redis_pool_size.zero?
$sidekiq_redis_timeout = sidekiq_config[:timeout]

poll_interval = config['scheduled_poll_interval']
Sidekiq.default_worker_options = { backtrace: 10 }
Sidekiq.configure_client do |config|
  config.redis = ConnectionPool.new(size: $sidekiq_client_redis_pool_size, timeout: $sidekiq_redis_timeout, &$sidekiq_datastore)
  config.client_middleware do |chain|
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
      "CountES::IndexOperations::DisableCountES",
      "Gamification::ProcessTicketQuests",
      "AccountCleanup::DeleteSpamTicketsCleanup",
      "AccountCleanup::SuspendedAccountsWorker",
      "Social::Gnip::ReplayWorker",
      "Social::Gnip::RuleWorker",
      "Reports::ScheduledReports",
      "Reports::BuildNoActivity",
      "Social::PremiumFacebookWorker",
      "Social::PremiumTwitterWorker",
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
      'Admin::Sandbox::UpdateSubscriptionWorker'
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
      'Freshid::V2::ProcessEvents'
    ]
  end
end

Sidekiq.configure_server do |config|
  # ActiveRecord::Base.logger = Logger.new(STDOUT)
  # Sidekiq::Logging.logger = ActiveRecord::Base.logger
  # Sidekiq::Logging.logger.level = ActiveRecord::Base.logger.level
  config.redis = ConnectionPool.new(:size => $sidekiq_redis_pool_size, :timeout => $sidekiq_redis_timeout, &$sidekiq_datastore)
  config.reliable_fetch!
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
  #https://forums.aws.amazon.com/thread.jspa?messageID=290781#290781
  #Making AWS as thread safe
  AWS.eager_autoload!
  config.server_middleware do |chain|
    chain.add Middleware::Sidekiq::Server::UnsetThread
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
      "CountES::IndexOperations::DisableCountES",
      "Gamification::ProcessTicketQuests",
      "AccountCleanup::DeleteSpamTicketsCleanup",
      "AccountCleanup::SuspendedAccountsWorker",
      "Social::Gnip::ReplayWorker",
      "Social::Gnip::RuleWorker",
      "Reports::ScheduledReports",
      "Reports::BuildNoActivity",
      "Social::PremiumFacebookWorker",
      "Social::PremiumTwitterWorker",
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
      'Admin::Sandbox::UpdateSubscriptionWorker'
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
      "ProductFeedbackWorker",
      "Community::MergeTopicsWorker",
      "Admin::Sandbox::DataToFileWorker",
      "Admin::Sandbox::FileToDataWorker",
      "Admin::Sandbox::DiffWorker",
      "Admin::Sandbox::MergeWorker",
      'Tickets::UndoSendWorker'
    ]

    chain.add Middleware::Sidekiq::Server::JobDetailsLogger
    chain.add Middleware::Sidekiq::Server::Throttler, :required_classes => ["WebhookV1Worker"]
  end
  config.client_middleware do |chain|
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
      "CountES::IndexOperations::DisableCountES",
      "Gamification::ProcessTicketQuests",
      "AccountCleanup::DeleteSpamTicketsCleanup",
      "AccountCleanup::SuspendedAccountsWorker",
      "Social::Gnip::ReplayWorker",
      "Social::Gnip::RuleWorker",
      "Reports::ScheduledReports",
      "Reports::BuildNoActivity",
      "Social::PremiumFacebookWorker",
      "Social::PremiumTwitterWorker",
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
      'Admin::Sandbox::UpdateSubscriptionWorker'
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
      'Tickets::UndoSendWorker'
    ]
  end
end
