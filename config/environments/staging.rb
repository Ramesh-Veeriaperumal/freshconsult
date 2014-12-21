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
  end

  # Don't auto compile css in production
  config.after_initialize do
  	Sass::Plugin.options[:never_update] = true
  end

  # Use a different cache store in production
  # config.cache_store = :mem_cache_store

  #ActiveRecord::Base.logger = Logger.new("log/debug.log")

  # Disable delivery errors, bad email addresses will be ignored
  # config.action_mailer.raise_delivery_errors = false

  config.after_initialize do
    Sass::Plugin.options[:never_update] = true
    ActiveMerchant::Billing::Base.gateway_mode = :test
  end   
  if defined?(PhusionPassenger)
    config.action_controller.asset_host = Proc.new { |source, request= nil, *_|
      asset_host_url = "https://d31jxxr9fvyo78.cloudfront.net" 
      asset_host_url = "http://assets%d.freshpo.com" % (rand(9)+1) if request && !request.ssl?
      asset_host_url
    }
  end
end


# Disable delivery errors, bad email addresses will be ignored
# config.action_mailer.raise_delivery_errors = false
