require "#{Rails.root}/lib/middleware/disable_assets_logger"
Helpkit::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  # cache classes to true for sidekiq to work properly
  config.cache_classes = false

  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils = true

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Only reloading classes if dependencies files changed
  config.reload_classes_only_on_change = false

  # Don't care if the mailer can't send
  config.action_mailer.raise_delivery_errors = true

  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log

  # Only use best-standards-support built into browsers
  config.action_dispatch.best_standards_support = :builtin

  # Raise exception on mass assignment protection for Active Record models
  config.active_record.mass_assignment_sanitizer = :logger

  # Log the query plan for queries taking more than this (works
  # with SQLite, MySQL, and PostgreSQL)
  config.active_record.auto_explain_threshold_in_seconds = 0.5

  # Do not compress assets
  config.assets.compress = false

  # No Digest paths for Development environment
  config.assets.digest = false

  config.log_tags = [:uuid]

  # Expands the lines which load the assets
  config.assets.debug = false

  #Enable Redis access tracking
  config.middleware.insert_before 0, 'Middleware::LogRedisCalls'
  config.middleware.insert_before Rails::Rack::Logger, Middleware::DisableAssetsLogger
  config.reload_plugins = true
  config.after_initialize do
    ActiveMerchant::Billing::Base.gateway_mode = :test
    Bullet.enable         = true
    Bullet.rails_logger   = true
    Bullet.bullet_logger  = true
    Bullet.console        = true
    # Other options can be found here: https://github.com/flyerhzm/bullet#configuration
  end
end

# YML related changes
FileUtils.cp('config/redis_development.yml', 'config/redis.yml')
FileUtils.cp('config/elasticsearch_development.yml', 'config/elasticsearch.yml')

if defined?(PhusionPassenger)
  PhusionPassenger.on_event(:starting_worker_process) do |forked|
    if forked
      $organisation_client = Freshworks::Organisation::V2::OrganisationService::Client.new
      $account_client = Freshworks::Account::V2::AccountService::Client.new
      $user_client = Freshworks::User::V2::UserService::Client.new
      $user_hash_client = Freshworks::User::V2::UserHashService::Client.new
      $bundle_client = Freshworks::Bundle::V2::BundleService::Client.new
    end
  end
end
