require File.expand_path('../boot', __FILE__)

require 'rails/all'

require 'rack/throttle'
require 'gapps_openid'
require File.expand_path('../../lib/facebook_routing', __FILE__)
require "rate_limiting"

if defined?(Bundler)
  # If you precompile assets before deploying to production, use this line
  Bundler.require(*Rails.groups(:assets => %w(development test)))
  # If you want your assets lazily compiled in production, use this line
  # Bundler.require(:default, :assets, Rails.env)
end

module Helpkit
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    # config.autoload_paths += %W(#{config.root}/extras)

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Activate observers that should always be running.
    # config.active_record.observers = :cacher, :garbage_collector, :forum_observer
    Dir.chdir("#{Rails.root}/app/observers") do
      config.active_record.observers = Dir.glob("**/*_observer.rb").collect {|ob_name| ob_name.split(".").first}
    end

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'
    config.time_zone = 'Chennai'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]

    # Enable escaping HTML in JSON.
    config.active_support.escape_html_entities_in_json = true

    # Use SQL instead of Active Record's schema dumper when creating the database.
    # This is necessary if your schema can't be completely dumped by the schema dumper,
    # like if you have constraints or database-specific column types
    # config.active_record.schema_format = :sql

    # Enforce whitelist mode for mass assignment.
    # This will create an empty whitelist of attributes available for mass-assignment for all models
    # in your app. As such, your models will need to explicitly whitelist or blacklist accessible
    # parameters by using an attr_accessible or attr_protected declaration.
    config.active_record.whitelist_attributes = false

    # Enable the asset pipeline
    config.assets.enabled = true

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = '1.0'

    config.action_controller.include_all_helpers = false

    # Configuring middlewares -- Game begins from here ;)
    config.middleware.use "Middleware::GlobalRestriction"
    config.middleware.use "Middleware::ApiThrottler", :max =>  1000
    config.middleware.use "Middleware::TrustedIp"
    config.middleware.insert_after "Middleware::GlobalRestriction",RateLimiting do |r|
      # during the ddos attack uncomment the below line
      # r.define_rule(:match => ".*", :type => :frequency, :metric => :rph, :limit => 200, :frequency_limit => 12, :per_ip => true ,:per_url => true )
      r.define_rule( :match => "^/(mobihelp)/.*", :type => :fixed, :metric => :rph, :limit => 20,:per_ip => true ,:per_url => true )
      r.define_rule( :match => "^/(support\/mobihelp)/.*", :type => :fixed, :metric => :rph, :limit => 100,:per_ip => true ,:per_url => true )
      r.define_rule( :match => "^/(support(?!\/(theme)))/.*", :type => :fixed, :metric => :rph, :limit => 1800,:per_ip => true ,:per_url => true )
      store = Redis.new(:host => RateLimitConfig["host"], :port => RateLimitConfig["port"])
      r.set_cache(store) if store.present?
    end

    # Plugins custom path and order
    config.plugin_paths =["#{Rails.root}/lib/plugins"]
    config.plugins = [ :belongs_to_account, :all ]

    # Make Time.zone default to the specified zone, and make Active Record store time values
    # in the database in UTC, and return them converted to the specified local zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Comment line to use default local time.
    config.time_zone = 'Chennai'

    # ActiveSupport::JSON.backend = "JSONGem"
    ActiveSupport::JSON.backend = :json_gem
    # Your secret key for verifying cookie session data integrity.
    # If you change this key, all old sessions will become invalid!
    # Make sure the secret is at least 30 characters and all random, 
    # no regular words or you'll be exposed to dictionary attacks.
    config.session_store(:cookie_store, {
        :session_key => '_helpkit_session'
    })

    config.action_controller.allow_forgery_protection = true

    # TODO-RAILS3 need to rewritten all lib files and adding requires if need to make it thread safe
    # http://hakunin.com/rails3-load-paths
    config.autoload_paths += Dir["#{config.root}/lib/"]


    # TODO-RAILS3 need to cross check
    require 'openid/store/filesystem'
    require 'omniauth'
    require 'omniauth/strategies/twitter'
    require 'omniauth/strategies/nimble'

    # you will be able to access the above providers by the following url
    # /auth/providername for example /auth/twitter /auth/facebook
    
    # TODO-RAILS3 need to cross check
    config.middleware.use  OmniAuth::Strategies::OpenID, :store => OpenID::Store::Filesystem.new('./omnitmp') , :name => "google",  :identifier => "https://www.google.com/accounts/o8/id"
    # you won't be able to access the openid urls like /auth/google
    # you will be able to access them through
    # /auth/open_id?openid_url=https://www.google.com/accounts/o8/id
    # /auth/open_id?openid_url=https://me.yahoo.com

    config.middleware.use OmniAuth::Builder do


      oauth_keys = Integrations::OauthHelper::get_oauth_keys
      oauth_keys.map { |oauth_provider, key_hash|
      if oauth_provider == "shopify"
        provider :shopify, key_hash["consumer_token"], key_hash["consumer_secret"],
                 :scope => 'read_orders',
                 :setup => lambda { |env| params = Rack::Utils.parse_query(env['QUERY_STRING'])
                 env['omniauth.strategy'].options[:client_options][:site] = "https://#{params['shop']}" }
      elsif key_hash["options"].blank?
          provider oauth_provider, key_hash["consumer_token"], key_hash["consumer_secret"]
      elsif key_hash["options"]["name"].blank?
        provider oauth_provider, key_hash["consumer_token"], key_hash["consumer_secret"], key_hash["options"]
      else
        provider oauth_provider, key_hash["consumer_token"], key_hash["consumer_secret"], { scope: key_hash["options"]["scope"], name: key_hash["options"]["name"] }
        key_hash["options"].delete "name"
        provider oauth_provider, key_hash["consumer_token"], key_hash["consumer_secret"], key_hash["options"]
      end
      }

      # OmniAuth.origin on failure callback; so get it via params
      # https://github.com/intridea/omniauth/issues/569
      on_failure do |env|
        message_key = env['omniauth.error.type']
        origin = env['omniauth.origin']
        new_path = "#{env['SCRIPT_NAME']}#{OmniAuth.config.path_prefix}/failure?message=#{message_key}"
        unless origin.blank?
          origin = origin.split('?').last
          new_path += "&origin=#{URI.escape(origin)}"
        end
        [302, {'Location' => new_path, 'Content-Type'=> 'text/html'}, []]
      end

      provider :open_id,  :store => OpenID::Store::Filesystem.new('./omnitmp')
    end


    config.filter_parameters += [:password, :password_confirmation, :creditcard]

    config.assets.paths += Dir["#{Rails.root}/public/*"].sort_by { |dir| -dir.size }


  end
end

require 'active_record/connection_adapters/abstract_mysql_adapter'
#Overridding datatype for primary key
ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter::NATIVE_DATABASE_TYPES[:primary_key] = "BIGINT UNSIGNED DEFAULT NULL auto_increment PRIMARY KEY"

# Captcha API Keys
ENV['RECAPTCHA_PUBLIC_KEY']  = '6LfNCb8SAAAAACxs6HxOshDa4nso_gyk0sxKcwAI'
ENV['RECAPTCHA_PRIVATE_KEY'] = '6LfNCb8SAAAAANC5TxzpWerRTLrxP3Hsfxw0hTNk'

module ActionView
  class Base
    # Specify whether RJS responses should be wrapped in a try/catch block
    # that alert()s the caught exception (and then re-raises it).
    cattr_accessor :debug_rjs
    @@debug_rjs = false
  end
end
