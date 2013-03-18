# Settings specified here will take precedence over those in config/environment.rb

# In the development environment your application's code is reloaded on
# every request.  This slows down response time but is perfect for development
# since you don't have to restart the webserver when you make code changes.
config.cache_classes = false

# Log error messages when you accidentally call methods on nil.
config.whiny_nils = true

# config.load_paths += %W( #{RAILS_ROOT}/lib )

# Show full error reports and disable caching
config.action_controller.consider_all_requests_local = true
config.action_view.debug_rjs                         = true
config.action_controller.perform_caching             = false
config.reload_plugins = true
ActionController::Base.asset_host =  Proc.new { |source, request|
  params = request.parameters
  if params['format'] == 'widget'
    "http://localhost:3000"
  end
}
# Don't care if the mailer can't send
config.action_mailer.raise_delivery_errors = true



config.after_initialize do
  ActiveMerchant::Billing::Base.gateway_mode = :test
end

require 'ftools'
File.copy('config/sphinx_development.yml', 'config/sphinx.yml', true)
File.copy('config/redis_development.yml', 'config/redis.yml', true)
