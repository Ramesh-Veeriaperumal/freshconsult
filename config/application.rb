require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Disable i18nema usage during asset compilation.
#
# During asset compilation, we use i18n-js to generate translation strings
# for js. i18n-js gem is using non-public member ('translations') of
# i18n.backend object which is not implemented in i18nema.
#
# Note that in development environment, asset compilation may happen on the
# fly, so we will disable i18nema for development as well.
if !Rails.env.development? && ENV['I18NEMA_ENABLE'] == 'true'
  require 'i18nema'
  I18n.backend = I18nema::Backend.new
end

require 'rack/throttle'
require 'gapps_openid'
require File.expand_path('../../lib/facebook_routing', __FILE__)
require File.expand_path('../../lib/locale_routing', __FILE__)
require "rate_limiting"
require "rack/ssl"
# require "statsd"

if defined?(Bundler)
  # If you precompile assets before deploying to production, use this line
  # Bundler.require(*Rails.groups(:assets => %w(development test)))
  # If you want your assets lazily compiled in production, use this line
  Bundler.require(:default, :assets, Rails.env)
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

    # api paths
    config.paths["config/routes"] << "config/api_routes.rb"
    config.paths["app/views"] << "api/app/views"
    config.paths["app/controllers"] << "api/app/controllers"
    config.paths["lib"] << "api/lib"

    # config.exceptions_app = ->(env) { ExceptionsController.action(:show).call(env) }

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}')]
    # config.i18n.default_locale = :de

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    # Filtering out Encrypted fields
    config.filter_parameters += [/^cf_enc_/]
    config.filter_parameters += [/^enc_/]

    # Other sensitive fields to be filtered out
    config.filter_parameters += [:password, :password_confirmation, :creditcard, :crypted_password, :password_salt, :card_number, :card_expiration]
    config.filter_parameters += [/token/]
    # Fields to be filtered to reduce the logging impact
    config.filter_parameters += [
      :description_html, :description, # Ticket bodies and Articles
      :raw_text, :raw_html, :body, :body_html, :full_text, :full_text_html, # Note bodies, Contact/Company bodies
      :desc_un_html # Articles
    ]

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
    #Raising an Exception if unpermitter parameters are used
    config.action_controller.action_on_unpermitted_parameters = :raise

    # Configuring middlewares -- Game begins from here ;)
    # statsd_config = YAML.load_file(File.join(Rails.root, 'config', 'statsd.yml'))[Rails.env]
    # statsd intialization
    # statsd = Statsd::Statsd.new(statsd_config["host"], statsd_config["port"])
    # middleware for statsd
    # config.middleware.use "Statsd::Rack::Middleware", statsd

    # Please check api_initializer.rb, for compatibility with the version 2 APIs, if any middleware related changes are being done.
    # Adding health check from haproxy as the first middleware.
    # If there are more than 2 middlewares with config.middleware.insert_before 0, the last one gets the precedence.
    # GlobalRequestStore should always before any business logic Middleware.
    # ApplicationLogger should always follow GlobalRequestStore.

    config.middleware.delete "ActiveRecord::QueryCache"
    config.middleware.insert_before 0, "Middleware::CorsEnabler"
    config.middleware.insert_before 0, "Middleware::SecurityResponseHeader"
    config.middleware.insert_before 0, "Middleware::ApplicationLogger" if ENV['MIDDLEWARE_LOG_ENABLE'] == 'true'
    config.middleware.insert_before 0, 'Middleware::GlobalTracer' unless Rails.env.test? || Rails.env.development?
    config.middleware.insert_before 0, 'Middleware::HealthCheck'
    config.middleware.insert_before 'Middleware::HealthCheck', 'Middleware::GlobalRequestStore'
    config.middleware.insert_after 'Middleware::GlobalRequestStore', 'Middleware::RequestInitializer'
    config.middleware.insert_before "ActionDispatch::Session::CookieStore","Rack::SSL"
    config.middleware.use "Middleware::GlobalRestriction" if ENV['ENABLE_GLOBAL_RESTRICTION_MIDDLEWARE'] == 'true'
    config.middleware.use "Middleware::ApiThrottler", :max =>  1000
    config.middleware.use "Middleware::TrustedIp"
    config.middleware.insert_before "Middleware::ApiThrottler",RateLimiting do |r|
      # during the ddos attack uncomment the below line
      # r.define_rule(:match => ".*", :type => :frequency, :metric => :rph, :limit => 200, :frequency_limit => 12, :per_ip => true ,:per_url => true )
      r.define_rule(match: "^(/[a-z]{2}(-[A-Z]{2})?)?\/support\/tickets\/check_email", type: :fixed, metric: :rpm, limit: 10, per_ip: true, per_url: true, include_host: true)
      r.define_rule(match: "^(/[a-z]{2}(-[A-Z]{2})?)?\/password_resets", type: :fixed, metric: :rpm, limit: 10, per_ip: true, per_url: true, include_host: true)
      r.define_rule(match: "^/(([a-z]{2}(-[A-Z]{2})?\/)?support(?!\/(theme)))/.*", type: :fixed, metric: :rpm, limit: 200, per_ip: true, per_url: true, include_host: true)
      r.define_rule(match: "^/(accounts\/new_signup_free).*", type: :fixed, metric: :rpd, limit: 5, per_ip: false, per_xff_ip: true)
      r.define_rule( :match => "^/(accounts\/email_signup).*", :type => :fixed, :metric => :rpd, :limit => 5,:per_ip => true)
      r.define_rule( :match => "^/(accounts\/anonymous_signup).*", :type => :fixed, :metric => :rpd, :limit => 5,:per_ip => true)
      r.define_rule( :match => "^/(public\/tickets)/.*", :type => :fixed, :metric => :rpm, :limit => 10,:per_ip => true)
      r.define_rule( :match => "^/(login\/sso).*", :type => :fixed, :metric => :rpm, :limit => 10,:per_ip => true)
      r.define_rule( :match => "^/integrations\/sugarcrm\/settings_update", :type => :fixed, :metric => :rph, :limit => 5,:per_ip => true)
      r.define_rule( :match => "^/export\/ticket_activities", :type => :fixed, :metric => :rph, :limit => 30, :per_url => true)

      redis_options = HashWithIndifferentAccess.new(RateLimitConfig.slice('host', 'port', 'password').merge('timeout' => 0.5))
      store = Redis.new(redis_options)
      r.set_cache(store) if store.present?
    end

    # Plugins custom path and order
    config.plugin_paths =["#{Rails.root}/lib/plugins"]
    config.plugins = [ :belongs_to_account, :all ]

    # Make Time.zone default to the specified zone, and make Active Record store time values
    # in the database in UTC, and return them converted to the specified local zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Comment line to use default local time.
    config.time_zone = 'Chennai'
    # https://www.rubydoc.info/gems/safe_yaml
    # Set default_mode to safe, which means YAML.load() will not deserialize arbitrary objects.
    # default_mode unsafe warning from gem loads yaml, SafeYaml may need to configure before bundler/setup. 
    # PRE-RAILS: Need to check and whitelist objects https://github.com/dtao/safe_yaml#known-issues, so check AR serialize and deseialize column. 
    # Need to add safe yaml default load before bundler so that gems yaml load will be safe. Ref: https://github.com/freshdesk/helpkit/commit/9286a16418ac
    SafeYAML::OPTIONS[:default_mode] = :unsafe
    SafeYAML::OPTIONS[:deserialize_symbols] = true

    # ActiveSupport::JSON.backend = "JSONGem"
    ActiveSupport::JSON.backend = :json_gem
    ActiveSupport::XmlMini.backend = 'Nokogiri'
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
    # http://blog.arkency.com/2014/11/dont-forget-about-eager-load-when-extending-autoload/
    config.eager_load_paths += Dir["#{config.root}/api/**/*"]
    # config.autoload_paths += %W(#{config.root}/api/app/validators/)
    # make sure to uncomment this for sidekiq workers
    config.eager_load_paths += Dir["#{config.root}/lib/"] unless Rails.env.development?


    # TODO-RAILS3 need to cross check
    require 'openid/store/filesystem'
    require 'omniauth'

    Dir[Rails.root+"lib/omniauth/strategies/*"].each do |file|
      require file
    end

    # you will be able to access the above providers by the following url
    # /auth/providername for example /auth/twitter /auth/facebook

    # TODO-RAILS3 need to cross check
    # you won't be able to access the openid urls like /auth/google
    # you will be able to access them through
    # /auth/open_id?openid_url=https://www.google.com/accounts/o8/id
    # /auth/open_id?openid_url=https://me.yahoo.com

    require "#{Rails.root}"+"/lib/auth/builder"

    config.middleware.use Auth::Builder do
      OmniAuth.config.logger = Rails.logger

      oauth_keys = Integrations::OauthHelper::get_oauth_keys
      oauth_keys.map do |oauth_provider, key_hash|
        next if Integrations::Constants::OAUTH_STRATEGIES_TO_SKIP.include?(oauth_provider)
        begin
          if key_hash['options'].blank?
            provider oauth_provider, key_hash['consumer_token'], key_hash['consumer_secret']
          else
            provider oauth_provider, key_hash['consumer_token'], key_hash['consumer_secret'], key_hash['options']
          end
        rescue LoadError => e
          puts "LoadError with the OAuth strategy, provider ~> #{oauth_provider}"
        end
      end

      # OmniAuth.origin on failure callback; so get it via params
      # https://github.com/intridea/omniauth/issues/569
      on_failure do |env|
        message_key = env['omniauth.error.type']
        origin = env['omniauth.origin']
        new_path = "#{env['SCRIPT_NAME']}#{OmniAuth.config.path_prefix}/failure?message=#{message_key}"
        if env['omniauth.error.strategy'].name == 'gmail'
          new_path = "#{env['SCRIPT_NAME']}#{OmniAuth.config.path_prefix}/gmail/failure?message=#{message_key}"
        end

        unless origin.blank?
          origin = origin.split('?').last
          new_path += "&origin=#{URI.escape(origin)}"
        end
        if env['omniauth.error.strategy'].present?
          new_path += "&provider=#{env['omniauth.error.strategy'].name}"
        end
        [302, {'Location' => new_path, 'Content-Type'=> 'text/html'}, []]
      end

      provider :open_id,  :store => OpenID::Store::Filesystem.new('./omnitmp')

      Auth::Authenticator.authenticators.values.each do |authenticator|
        authenticator.new.register_middleware(self)
      end
    end

    config.assets.paths += (Dir["#{Rails.root}/public/*"] - ["#{Rails.root}/public/assets"]).sort_by { |dir| -dir.size }

    config.assets.digest = true
    config.assets.precompile = ["cdn/*"]

    # prevent Rails from initializing the Rails environment
    # and looking at database.yml when running rake assets:precompile
    config.assets.initialize_on_precompile = false

    config.middleware.insert_before "ActionDispatch::Cookies","Rack::SSL"
    config.middleware.insert_before "Auth::Builder","Middleware::Pod"
    config.middleware.insert_after 'Middleware::SecurityResponseHeader', 'Middleware::PodRedirect'

    config.assets.handle_expiration = true
    config.assets.expire_after= 2.months
  end
end

require 'active_record/connection_adapters/abstract_mysql_adapter'
#Overridding datatype for primary key
ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter::NATIVE_DATABASE_TYPES[:primary_key] = "BIGINT UNSIGNED NOT NULL auto_increment PRIMARY KEY"


# reCAPTCHA API Keys
recaptcha_file = File.join(Rails.root, 'config', 'recaptcha_v2.yml')
YAML.load(File.open(recaptcha_file)).each do |key, value|
  ENV[key]  = value
end if File.exists? recaptcha_file


GC::Profiler.enable if defined?(GC) && defined?(GC::Profiler) && GC::Profiler.respond_to?(:enable)

# Enabling rbtrace is useful to get callstack and other runtime information.
# There is no overhead unless we invoke rbtrace and attach the pid.
if defined?(PhusionPassenger) # rbtrace should be enabled only after passenger starts(for foreground jobs)
  PhusionPassenger.on_event(:after_installing_signal_handlers) do
    require 'rbtrace'
  end
else
  require 'rbtrace' # For background jobs
end
