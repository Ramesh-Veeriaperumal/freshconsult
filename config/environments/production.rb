# Settings specified here will take precedence over those in config/environment.rb

# The production environment is meant for finished, "live" apps.
# Code is not reloaded between requests
config.log_level = :debug

config.cache_classes = true
config.action_controller.allow_forgery_protection = true
# Use a different logger for distributed setups
# config.logger = SyslogLogger.new

# Full error reports are disabled and caching is turned on
config.action_controller.consider_all_requests_local = false
config.action_controller.perform_caching             = true
config.action_view.cache_template_loading            = true


#ActiveRecord::Base.logger = Logger.new("log/debug.log")
# Don't auto compile css in production
config.after_initialize do
	Sass::Plugin.options[:never_update] = true
end

# Use a different cache store in production
# config.cache_store = :mem_cache_store

# Enable serving of images, stylesheets, and javascripts from an asset server
# config.action_controller.asset_host                  = "http://assets.example.com"
ActionController::Base.asset_host =  Proc.new { |source, request|
  params = request.parameters
  if params['format'] == 'widget'
    "https://asset.freshdesk.com"
  end
}

config.middleware.insert_before "ActionController::Session::CookieStore","Rack::SSL"
config.middleware.insert_after "Middleware::GlobalRestriction",RateLimiting do |r|
  # during the ddos attack uncomment the below line
  # r.define_rule(:match => ".*", :type => :frequency, :metric => :rph, :limit => 200, :frequency_limit => 12, :per_ip => true ,:per_url => true )
  r.define_rule( :match => "^/(mobihelp)/.*", :type => :fixed, :metric => :rph, :limit => 300,:per_ip => true ,:per_url => true )
  r.define_rule( :match => "^/(support\/mobihelp)/.*", :type => :fixed, :metric => :rph, :limit => 300,:per_ip => true ,:per_url => true )
  r.define_rule( :match => "^/(support(?!\/(theme)))/.*", :type => :fixed, :metric => :rph, :limit => 1800,:per_ip => true ,:per_url => true )
  r.define_rule( :match => "^/(accounts\/new_signup_free).*", :type => :fixed, :metric => :rpd, :limit => 5,:per_ip => true)
  r.define_rule( :match => "^/(public\/tickets)/.*", :type => :fixed, :metric => :rph, :limit => 30,:per_ip => true)
  store = Redis.new(:host => RateLimitConfig["host"], :port => RateLimitConfig["port"])
  r.set_cache(store) if store.present?
end
config.middleware.insert_before "ActionController::Session::CookieStore","Rack::SSL"
# loading statsd configuration
statsd_config = YAML.load_file(File.join(Rails.root, 'config', 'statsd.yml'))[Rails.env]
# statsd intialization
statsd = Statsd::Statsd.new(statsd_config["host"], statsd_config["port"])
# middleware for statsd
config.middleware.use "Statsd::Rack::Middleware", statsd

# Disable delivery errors, bad email addresses will be ignored
# config.action_mailer.raise_delivery_errors = false
