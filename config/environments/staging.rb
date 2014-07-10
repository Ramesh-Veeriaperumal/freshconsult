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
config.action_controller.consider_all_requests_local = false
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

# Enable serving of images, stylesheets, and javascripts from an asset server
# config.action_controller.asset_host                  = "http://assets.example.com"
ActionController::Base.asset_host =  Proc.new { |source, request|
  params = request.parameters
  if params['format'] == 'widget'
    "https://asset.freshpo.com"
  end
}

config.middleware.insert_after "Middleware::GlobalRestriction",RateLimiting do |r|
  r.define_rule( :match => "^/(support(?!\/(theme)))/.*", :type => :fixed, :metric => :rph, :limit => 1800,:per_ip => true ,:per_url => true )
  store = Redis.new(:host => RateLimitConfig["host"], :port => RateLimitConfig["port"])
  r.set_cache(store) if store.present?
end

# Disable delivery errors, bad email addresses will be ignored
# config.action_mailer.raise_delivery_errors = false