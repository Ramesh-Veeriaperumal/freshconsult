Helpkit::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb
  # The test environment is used exclusively to run your application's
  # test suite. You never need to work with it otherwise. Remember that
  # your test database is "scratch space" for the test suite and is wiped
  # and recreated between test runs. Don't rely on the data there!
  config.cache_classes = true

  # Configure static asset server for tests with Cache-Control for performance
  config.serve_static_assets = true
  config.static_cache_control = "public, max-age=3600"

  # Log error messages when you accidentally call methods on nil
  config.whiny_nils = true

  # Show full error reports and disable caching
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = false

  # Raise exceptions instead of rendering exception templates
  config.action_dispatch.show_exceptions = false

  # Disable request forgery protection in test environment
  config.action_controller.allow_forgery_protection    = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  config.action_mailer.perform_deliveries = false

  # Do not compress assets
  config.assets.compress = false

  # No Digest paths for Development environment
  config.assets.digest = false

  # Expands the lines which load the assets
  config.assets.debug = true

  # Raise exception on mass assignment protection for Active Record models
  config.active_record.mass_assignment_sanitizer = :logger

  # Print deprecation notices to the stderr
  config.active_support.deprecation = :stderr

  #disable Api Throttler
  config.middleware.delete 'Middleware::ApiThrottler'

  config.after_initialize do
    Bullet.enable         = true
    Bullet.bullet_logger  = true
    Bullet.rails_logger   = true
    Bullet.raise          = false # raise an error if n+1 query occurs
    Bullet.unused_eager_loading_enable = false
    # Other options can be found here: https://github.com/flyerhzm/bullet#configuration
  end
end

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

# Faker:1.4.3 sets this to true.
# To ensure consistency in development, staging, production, and test environments, resetting `enforce_available_locales` variable to false
I18n.enforce_available_locales = false
