# Settings specified here will take precedence over those in config/environment.rb

# The test environment is used exclusively to run your application's
# test suite.  You never need to work with it otherwise.  Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs.  Don't rely on the data there!

require 'yaml'
YAML::ENGINE.yamler = 'syck'

config.cache_classes = true

# Log error messages when you accidentally call methods on nil.
config.whiny_nils = true

# Show full error reports and disable caching
config.action_controller.consider_all_requests_local = true
config.action_controller.perform_caching             = false

# Disable request forgery protection in test environment
config.action_controller.allow_forgery_protection    = false

# Tell Action Mailer not to deliver emails to the real world.
# The :test delivery method accumulates sent emails in the
# ActionMailer::Base.deliveries array.
config.action_mailer.delivery_method = :test
config.action_mailer.perform_deliveries = false
config.middleware.insert_before "ActionController::Session::CookieStore","Rack::SSL"
config.middleware.insert_after "Middleware::GlobalRestriction",RateLimiting do |r|
  r.define_rule( :match => "^/(support(?!\/(theme)))/.*", :type => :fixed, :metric => :rph, :limit => 10,:per_ip => true ,:per_url => true )
  store = Redis.new(:host => RateLimitConfig["host"], :port => RateLimitConfig["port"])
  r.set_cache(store) if store.present?
end

# config.gem "thoughtbot-shoulda", :lib => 'shoulda', :source => "http://gems.github.com"

# config.gem 'rspec-rails', :version => '>= 1.3.2', :lib => false unless File.directory?(File.join(Rails.root, 'vendor/plugins/rspec-rails'))

# config.gem 'factory_girl', :version => '1.2.3'


