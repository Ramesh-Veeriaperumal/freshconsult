config = YAML::load_file(File.join(Rails.root, 'config', 'sidekiq.yml'))[Rails.env]
sidekiq_config = YAML::load_file(File.join(Rails.root, 'config', 'sidekiq_client.yml'))[Rails.env]

$sidekiq_conn = Redis.new(:host => config["host"], :port => config["port"])
$sidekiq_datastore = proc { Redis::Namespace.new(config["namespace"], :redis => $sidekiq_conn) }
$sidekiq_redis_pool_size = sidekiq_config[:redis_pool_size] || sidekiq_config[:concurrency]
$sidekiq_redis_timeout = sidekiq_config[:timeout]


Sidekiq.configure_client do |config|
  config.redis = ConnectionPool.new(:size => 1, :timeoout => $sidekiq_redis_timeout, &$sidekiq_datastore)
  config.client_middleware do |chain|
    chain.add Middleware::Sidekiq::Client::BelongsToAccount, :ignore => [
      "Social::TwitterReplyStreamWorker",
      "RabbitmqWorker",
      "Tickets::SelectAll::BatcherWorker",
      "Sidekiq::Batch::Callback",
      "Freshfone::CallQueueWorker",
      "Ecommerce::EbayWorker",
      "Ecommerce::EbayUserWorker",
      "PasswordExpiryWorker",
      "WebhookV1Worker",
      "DevNotificationWorker",
      "PodDnsUpdate",
      "SearchV2::Manager::DisableSearch",
      "Gamification::ProcessTicketQuests",
      "AccountCleanup::DeleteSpamTicketsCleanup",
      "AccountCleanup::SuspendedAccountsWorker",
      "Social::Gnip::ReplayWorker",
      "Social::Gnip::RuleWorker",
      "Reports::ScheduledReports",
      "Social::PremiumFacebookWorker",
      "Social::PremiumTwitterWorker"
    ]
    chain.add Middleware::Sidekiq::Client::SetCurrentUser, :required_classes => [
      "Tickets::BulkScenario",
      "Tickets::BulkTicketActions",
      "Tickets::BulkTicketReply",
      "Tickets::ClearTickets::EmptySpam",
      "Tickets::ClearTickets::EmptyTrash",
      "MergeTickets",
      "Export::ContactWorker",
      "Tickets::Export::TicketsExport",
      "Tickets::Export::LongRunningTicketsExport",
      "Tickets::Export::PremiumTicketsExport",
      "Reports::ScheduledReports",
      "Reports::Export",
      "LivechatWorker"
    ]
  end
end

Sidekiq.configure_server do |config|
  # ActiveRecord::Base.logger = Logger.new(STDOUT)
  # Sidekiq::Logging.logger = ActiveRecord::Base.logger
  # Sidekiq::Logging.logger.level = ActiveRecord::Base.logger.level
  config.redis = ConnectionPool.new(:size => $sidekiq_redis_pool_size, :timeoout => $sidekiq_redis_timeout, &$sidekiq_datastore)
  config.reliable_fetch!
  #https://forums.aws.amazon.com/thread.jspa?messageID=290781#290781
  #Making AWS as thread safe
  AWS.eager_autoload!
  config.server_middleware do |chain|
    chain.add Middleware::Sidekiq::Server::BelongsToAccount, :ignore => [
      "Social::TwitterReplyStreamWorker",
      "RabbitmqWorker",
      "Tickets::SelectAll::BatcherWorker",
      "Sidekiq::Batch::Callback",
      "Freshfone::CallQueueWorker",
      "Ecommerce::EbayWorker",
      "Ecommerce::EbayUserWorker",
      "PasswordExpiryWorker",
      "WebhookV1Worker",
      "DevNotificationWorker",
      "PodDnsUpdate",
      "SearchV2::Manager::DisableSearch",
      "Gamification::ProcessTicketQuests",
      "AccountCleanup::DeleteSpamTicketsCleanup",
      "AccountCleanup::SuspendedAccountsWorker",
      "Social::Gnip::ReplayWorker",
      "Social::Gnip::RuleWorker",
      "Reports::ScheduledReports",
      "Social::PremiumFacebookWorker",
      "Social::PremiumTwitterWorker"
    ]
    chain.add Middleware::Sidekiq::Server::SetCurrentUser, :required_classes => [
      "Tickets::BulkScenario",
      "Tickets::BulkTicketActions",
      "Tickets::BulkTicketReply",
      "Tickets::ClearTickets::EmptySpam",
      "Tickets::ClearTickets::EmptyTrash",
      "MergeTickets",
      "Export::ContactWorker",
      "Tickets::Export::TicketsExport",
      "Tickets::Export::LongRunningTicketsExport",
      "Tickets::Export::PremiumTicketsExport",
      "Reports::Export",
      "LivechatWorker"
    ]

    chain.add Middleware::Sidekiq::Server::JobDetailsLogger
    chain.add Middleware::Sidekiq::Server::Throttler, :required_classes => ["WebhookV1Worker"]
  end
  config.client_middleware do |chain|
    chain.add Middleware::Sidekiq::Client::BelongsToAccount, :ignore => [
      "Social::TwitterReplyStreamWorker",
      "RabbitmqWorker",
      "Tickets::SelectAll::BatcherWorker",
      "Sidekiq::Batch::Callback",
      "Freshfone::CallQueueWorker",
      "Ecommerce::EbayWorker",
      "Ecommerce::EbayUserWorker",
      "PasswordExpiryWorker",
      "WebhookV1Worker",
      "DevNotificationWorker",
      "SearchV2::Manager::DisableSearch",
      "Gamification::ProcessTicketQuests",
      "AccountCleanup::DeleteSpamTicketsCleanup",
      "AccountCleanup::SuspendedAccountsWorker",
      "Social::Gnip::ReplayWorker",
      "Social::Gnip::RuleWorker",
      "Reports::ScheduledReports",
      "Social::PremiumFacebookWorker",
      "Social::PremiumTwitterWorker"
    ]
    chain.add Middleware::Sidekiq::Client::SetCurrentUser, :required_classes => [
      "Tickets::BulkScenario",
      "Tickets::BulkTicketActions",
      "Tickets::BulkTicketReply",
      "Tickets::ClearTickets::EmptySpam",
      "Tickets::ClearTickets::EmptyTrash",
      "MergeTickets",
      "Export::ContactWorker",
      "Tickets::Export::TicketsExport",
      "Tickets::Export::LongRunningTicketsExport",
      "Tickets::Export::PremiumTicketsExport",
      "Reports::Export",
      "LivechatWorker"
    ]
  end
end
