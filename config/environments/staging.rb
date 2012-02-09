# Settings specified here will take precedence over those in config/environment.rb

# The production environment is meant for finished, "live" apps.
# Code is not reloaded between requests
config.log_level = :debug

config.cache_classes = false

# Use a different logger for distributed setups
# config.logger = SyslogLogger.new

# Full error reports are disabled and caching is turned on
config.action_controller.consider_all_requests_local = false
config.action_controller.perform_caching             = true
config.action_view.cache_template_loading            = true
#config.reload_plugins = true

config.after_initialize do
  ActiveMerchant::Billing::Base.gateway_mode = :test
end


# Use a different cache store in production
# config.cache_store = :mem_cache_store

# Enable serving of images, stylesheets, and javascripts from an asset server
# config.action_controller.asset_host                  = "http://assets.example.com"
ActionController::Base.asset_host =  Proc.new { |source, request|
  params = request.parameters
  if params['format'] == 'widget'
    "http://assets.freshpo.com"
  end
}
# Disable delivery errors, bad email addresses will be ignored
# config.action_mailer.raise_delivery_errors = false