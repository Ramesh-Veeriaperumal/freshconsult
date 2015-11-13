Helpkit::Application.configure do
  # Settings specified here will take precedence over those in config/environment.rb

  # The production environment is meant for finished, "live" apps.
  # Code is not reloaded between requests
  config.log_level = :debug

  config.cache_classes = true
  config.action_controller.allow_forgery_protection = true

  # Use a different logger for distributed setups
  # config.logger = SyslogLogger.new

  #ActiveRecord::Base.logger = Logger.new("log/debug.log")

  # Full error reports are disabled and caching is turned on
  config.action_controller.perform_caching             = true
  config.action_view.cache_template_loading            = true
  # config.reload_plugins = true

  config.after_initialize do
    ActiveMerchant::Billing::Base.gateway_mode = :test
    Bullet.enable         = true
    Bullet.bullet_logger  = true
    Bullet.console        = true
  end

  # Don't auto compile css in production
  config.after_initialize do
  	Sass::Plugin.options[:never_update] = true
  end

  # Use a different cache store in production
  # config.cache_store = :mem_cache_store

  #ActiveRecord::Base.logger = Logger.new("log/debug.log")

  # Prepend all log lines with the following tags
  config.log_tags = [:uuid]

  # Disable delivery errors, bad email addresses will be ignored
  # config.action_mailer.raise_delivery_errors = false

  config.after_initialize do
    Sass::Plugin.options[:never_update] = true
    ActiveMerchant::Billing::Base.gateway_mode = :test
  end   
  config.middleware.insert_after "Middleware::GlobalRestriction",RateLimiting do |r|
    # during the ddos attack uncomment the below line
    # r.define_rule(:match => ".*", :type => :frequency, :metric => :rph, :limit => 200, :frequency_limit => 12, :per_ip => true ,:per_url => true )
    r.define_rule( :match => "^/(mobihelp)/.*", :type => :fixed, :metric => :rph, :limit => 100,:per_ip => true ,:per_url => true )
    r.define_rule( :match => "^/(support\/mobihelp)/.*", :type => :fixed, :metric => :rph, :limit => 100,:per_ip => true ,:per_url => true )
    r.define_rule( :match => "^/(support(?!\/(theme)))/.*", :type => :fixed, :metric => :rph, :limit => 100,:per_ip => true ,:per_url => true )
    r.define_rule( :match => "^/(accounts\/new_signup_free).*", :type => :fixed, :metric => :rpd, :limit => 5,:per_ip => true)
    r.define_rule( :match => "^/(public\/tickets)/.*", :type => :fixed, :metric => :rph, :limit => 10,:per_ip => true)
    store = Redis.new(:host => RateLimitConfig["host"], :port => RateLimitConfig["port"])
    r.set_cache(store) if store.present?
  end
  if defined?(PhusionPassenger)
    config.action_controller.asset_host = Proc.new { |source, request= nil, *_|
      asset_host_url = $asset_sync_https_url
      asset_host_url = $asset_sync_http_url % (rand(9)+1) if request && !request.ssl?
      asset_host_url
    }
  end
end


# Disable delivery errors, bad email addresses will be ignored
# config.action_mailer.raise_delivery_errors = false
