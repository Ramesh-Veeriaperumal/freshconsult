Helpkit::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # Code is not reloaded between requests
  config.cache_classes = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Disable Rails's static asset server (Apache or nginx will already do this)
  config.serve_static_assets = true

  # Compress JavaScripts and CSS
  config.assets.compress = true

  # Don't fallback to assets pipeline if a precompiled asset is missed
  config.assets.compile = true

  # Generate digests for assets URLs
  config.assets.digest = true

  # Defaults to nil and saved in location specified by config.assets.prefix
  # config.assets.manifest = YOUR_PATH

  # Specifies the header that your server uses for sending files
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for nginx

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # See everything in the log (default is :info)
  config.log_level = :debug

  config.active_record.mass_assignment_sanitizer = :logger

  # Prepend all log lines with the following tags
  config.log_tags = [:uuid]

  # Use a different logger for distributed setups
  # config.logger = ActiveSupport::TaggedLogging.new(SyslogLogger.new)

  # Use a different cache store in production
  # config.cache_store = :mem_cache_store

  # Enable serving of images, stylesheets, and JavaScripts from an asset server
  # config.action_controller.asset_host = "http://assets.example.com"

  # Precompile additional assets (application.js, application.css, and all non-JS/CSS are already added)
  # config.assets.precompile += %w( search.js )

  # Disable delivery errors, bad email addresses will be ignored
  config.action_mailer.raise_delivery_errors = true

  # Enable threaded mode
  # config.threadsafe!

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found)
  config.i18n.fallbacks = true
  # PRE-RAILS: If you're using I18n (>= 1.1.0) and Rails (< 5.2.2), fallback should be changed as below
  # ref - https://github.com/ruby-i18n/i18n/releases/tag/v1.1.0
  # config.i18n.fallbacks = [I18n.default_locale]

  # Send deprecation notices to registered listeners
  config.active_support.deprecation = :notify

  #Enable Redis access tracking
  config.middleware.insert_before 0, 'Middleware::LogRedisCalls'

  # Log the query plan for queries taking more than this (works
  # with SQLite, MySQL, and PostgreSQL)
  # config.active_record.auto_explain_threshold_in_seconds = 0.5

  config.after_initialize do
    Sass::Plugin.options[:never_update] = true
    Bullet.enable         = true
    Bullet.bullet_logger  = true
  end

  # Need to set records for assets1..10.freshdesk.com
  if defined?(PhusionPassenger)
    config.action_controller.asset_host = Proc.new { |source, request= nil, *_|
      $asset_sync_https_url.sample
    }
    PhusionPassenger.on_event(:starting_worker_process) do |forked|
      if forked
        $organisation_client = Freshworks::Organisation::V2::OrganisationService::Client.new
        $account_client = Freshworks::Account::V2::AccountService::Client.new
        $user_client = Freshworks::User::V2::UserService::Client.new
        $user_hash_client = Freshworks::User::V2::UserHashService::Client.new
      end
    end
  end

end