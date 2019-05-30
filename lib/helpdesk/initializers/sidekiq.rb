config = YAML::load_file(File.join(Rails.root, 'config', 'sidekiq.yml'))[Rails.env]
sidekiq_config = YAML::load_file(File.join(Rails.root, 'config', 'sidekiq_client.yml'))[Rails.env]

SIDEKIQ_CLASSIFICATION = YAML::load_file(File.join(Rails.root, 'config', 'sidekiq_classification.yml'))

SIDEKIQ_CLASSIFICATION_MAPPING = SIDEKIQ_CLASSIFICATION[:classification].inject({}) do |t_h, queue|
  queue.last.each do |q|
    t_h[q] = queue.first
  end
  t_h
end

$sidekiq_datastore = proc { Redis::Namespace.new(config["namespace"], :redis => $sidekiq_conn) }
$sidekiq_redis_pool_size = sidekiq_config[:redis_pool_size] || sidekiq_config[:concurrency]
$sidekiq_redis_timeout = sidekiq_config[:timeout]


Sidekiq.configure_client do |config|
  config.redis = ConnectionPool.new(:size => 1, :timeout => $sidekiq_redis_timeout, &$sidekiq_datastore)
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
      "Tickets::Schedule",
      "Tickets::Dump",
      "BlockAccount",
      "Freshid::ProcessEvents",
      "CRMApp::Freshsales::Signup",
      "CRMApp::Freshsales::AdminUpdate",
      "CRMApp::Freshsales::TrackSubscription",
      'Freshid::V2::ProcessEvents',
      'Freshid::AccountDetailsUpdate',
      'Freshid::V2::AccountDetailsUpdate',
      'FreshidRetryWorker'
      
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
      "Admin::ProvisionSandbox",
      "Tickets::LinkTickets",
      "BroadcastMessages::NotifyBroadcastMessages",
      "BroadcastMessages::NotifyAgent",
      "Import::SkillWorker",
      "ExportAgents",
      "CollabNotificationWorker",
      "ProductFeedbackWorker",
      "Freshid::ProcessEvents",
      "Community::MergeTopicsWorker",
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
  #https://forums.aws.amazon.com/thread.jspa?messageID=290781#290781
  #Making AWS as thread safe
  AWS.eager_autoload!
  config.server_middleware do |chain|
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
      "Tickets::Schedule",
      "Tickets::Dump",
      "BlockAccount",
      "Freshid::ProcessEvents",
      "CRMApp::Freshsales::Signup",
      "CRMApp::Freshsales::AdminUpdate",
      "CRMApp::Freshsales::TrackSubscription",
      'Freshid::V2::ProcessEvents',
      'Freshid::AccountDetailsUpdate',
      'Freshid::V2::AccountDetailsUpdate',
      'FreshidRetryWorker'
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
      "Admin::ProvisionSandbox",
      "Tickets::LinkTickets",
      "BroadcastMessages::NotifyBroadcastMessages",
      "BroadcastMessages::NotifyAgent",
      "Import::SkillWorker",
      "ExportAgents",
      "CollabNotificationWorker",
      "ProductFeedbackWorker",
      "Community::MergeTopicsWorker"
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
      "Ecommerce::EbayWorker",
      "Ecommerce::EbayUserWorker",
      "PasswordExpiryWorker",
      "WebhookV1Worker",
      "SendSignupActivationMail",
      "DevNotificationWorker",
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
      "AccountCreation::PopulateSeedData",
      "Tickets::Schedule",
      "Tickets::Dump",
      "BlockAccount",
      "Freshid::ProcessEvents",
      "CRMApp::Freshsales::Signup",
      "CRMApp::Freshsales::AdminUpdate",
      "CRMApp::Freshsales::TrackSubscription",
      'Freshid::V2::ProcessEvents',
      'Freshid::AccountDetailsUpdate',
      'Freshid::V2::AccountDetailsUpdate',
      'FreshidRetryWorker'
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
      "Admin::ProvisionSandbox",
      "Tickets::LinkTickets",
      "BroadcastMessages::NotifyBroadcastMessages",
      "BroadcastMessages::NotifyAgent",
      "Import::SkillWorker",
      "ExportAgents",
      "CollabNotificationWorker",
      "ProductFeedbackWorker",
      "Community::MergeTopicsWorker"
    ]
  end
end
