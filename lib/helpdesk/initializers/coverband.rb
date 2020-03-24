if ENV['ENABLE_COVERBAND'] == "1" && Rails.env.staging?
  require 'coverband'
  require 'coverband/tasks'
   Coverband.configure do |config|
    config.root   = Dir.pwd
    config.redis  = $redis_others
    config.logger = Rails.logger
    # configure S3 integration
    config.s3_bucket = 'coverband-report'
    config.percentage = 100.0

    # config options false, true. (defaults to false)
    # true and debug can give helpful and interesting code usage information
    # and is safe to use if one is investigating issues in production, but it will slightly
    # hit perf.
    config.verbose = true
  end
  Rails.application.config.middleware.insert_before 0, "Coverband::Middleware"
end
