config = YAML::load_file(File.join(Rails.root, 'config', 'sidekiq.yml'))[Rails.env]

$sidekiq_conn = Redis.new(:host => config["host"], :port => config["port"])
$sidekiq_datastore = proc { Redis::Namespace.new(config["namespace"], :redis => $sidekiq_conn) }

Sidekiq.configure_client do |config|
  config.redis = ConnectionPool.new(:size => 5, &$sidekiq_datastore)
  config.client_middleware do |chain|
    chain.add Middleware::Sidekiq::Client::BelongsToAccount, :ignore => [
      "SlaScheduler",
      "Social::TwitterReplyStreamWorker"
    ]
  end
end

Sidekiq.configure_server do |config|
  # ActiveRecord::Base.logger = Logger.new(STDOUT)
  # Sidekiq::Logging.logger = ActiveRecord::Base.logger
  # Sidekiq::Logging.logger.level = ActiveRecord::Base.logger.level
  config.redis = ConnectionPool.new(:size => 5, &$sidekiq_datastore)
  #https://forums.aws.amazon.com/thread.jspa?messageID=290781#290781
  #Making AWS as thread safe
  AWS.eager_autoload!
  config.server_middleware do |chain|
    chain.add Middleware::Sidekiq::Server::BelongsToAccount, :ignore => [
      "SlaScheduler",
      "Social::TwitterReplyStreamWorker"
    ]
  end
  config.client_middleware do |chain|
    chain.add Middleware::Sidekiq::Client::BelongsToAccount, :ignore => [
      "SlaScheduler",
      "Social::TwitterReplyStreamWorker"
    ]
  end
end
