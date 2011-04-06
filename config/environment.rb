# Be sure to restart your server when you modify this file

# Uncomment below to force Rails into production mode when
# you don't control web/app server and can't set it the proper way
# ENV['RAILS_ENV'] ||= 'production'

# Specifies gem version of Rails to use when vendor/rails is not present
#RAILS_GEM_VERSION = '2.3.3' unless defined? RAILS_GEM_VERSION

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

require 'gapps_openid'

module ActionController
  class Request
    def scheme
      if @env['HTTPS'] == 'on'
        'https'
      elsif @env['HTTP_X_FORWARDED_SSL'] == 'on'
        'https'
      elsif @env['HTTP_X_FORWARDED_PROTO']
        @env['HTTP_X_FORWARDED_PROTO'].split(',')[0]
      else
        @env["rack.url_scheme"]
      end
    end

    def ssl?
      scheme == 'https'
    end

    def host_with_port
      if forwarded = @env["HTTP_X_FORWARDED_HOST"]
        forwarded.split(/,\s?/).last
      else
        @env['HTTP_HOST'] || "#{@env['SERVER_NAME'] || @env['SERVER_ADDR']}:#{@env['SERVER_PORT']}"
      end
    end

    def port
      if port = host_with_port.split(/:/)[1]
        port.to_i
      elsif port = @env['HTTP_X_FORWARDED_PORT']
        port.to_i
      elsif ssl?
        443
      elsif @env.has_key?("HTTP_X_FORWARDED_HOST")
        80
      else
        @env["SERVER_PORT"].to_i
      end
    end
  end
end

Rails::Initializer.run do |config|
  # Settings in config/environments/* take precedence over those specified here.
  # Application configuration should go into files in config/initializers
  # -- all .rb files in that directory are automatically loaded.
  # See Rails::Configuration for more options.

  # Skip frameworks you're not going to use. To use Rails without a database
  # you must remove the Active Record framework.
  # config.frameworks -= [ :active_record, :active_resource, :action_mailer ]

  # Specify gems that this application depends on. 
  # They can then be installed with "rake gems:install" on new installations.
  #config.gem "mms2r" #3.2.0
  #config.gem "classifier" LOCAL /vendor/gems
  #config.gem "stemmer" LOCAL
  #config.gem "lockfile" #from SAAS kit LOCAL
  # config.gem "bj"
  # config.gem "hpricot", :version => '0.6', :source => "http://code.whytheluckystiff.net"

  #config.gem 'delayed_job' :version => '1.8.4' #just a reference for using it along with ts-delayed-delta. 
  #otherwise ts-del** will install the latest version of delayed_job. 


  # Only load the plugins named here, in the order given. By default, all plugins 
  # in vendor/plugins are loaded in alphabetical order.
  # :all can be used as a placeholder for all plugins not explicitly named
  # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

  # Add additional load paths for your own custom dirs
  # config.load_paths += %W( #{RAILS_ROOT}/extras )
  
  #To load all the i18n files
  #config.i18n.load_path += Dir[File.join(RAILS_ROOT, 'config', 'locales', '**', '*.{rb,yml}')]

  # Force all environments to use the same logger level
  # (by default production uses :info, the others :debug)
  # config.log_level = :debug

  # Make Time.zone default to the specified zone, and make Active Record store time values
  # in the database in UTC, and return them converted to the specified local zone.
  # Run "rake -D time" for a list of tasks for finding time zone names. Comment line to use default local time.
  config.time_zone = 'Chennai'

  # Your secret key for verifying cookie session data integrity.
  # If you change this key, all old sessions will become invalid!
  # Make sure the secret is at least 30 characters and all random, 
  # no regular words or you'll be exposed to dictionary attacks.
  config.action_controller.session = {
    :session_key => '_helpkit_session',
    :secret      => '3f1fd135e84c2a13c212c11ff2f4b205725faf706345716f4b6996f9f8f2e6472f5784076c4fe102f4c6eae50da0fa59a9cc8cf79fb07ecc1eef62e9d370227f'
  }
  
  ENV['RECAPTCHA_PUBLIC_KEY']  = '6LfNCb8SAAAAACxs6HxOshDa4nso_gyk0sxKcwAI'
  ENV['RECAPTCHA_PRIVATE_KEY'] = '6LfNCb8SAAAAANC5TxzpWerRTLrxP3Hsfxw0hTNk'

  # Use the database for sessions instead of the cookie-based default,
  # which shouldn't be used to store highly confidential information
  # (create the session table with "rake db:sessions:create")
  # config.action_controller.session_store = :active_record_store

  # Use SQL instead of Active Record's schema dumper when creating the test database.
  # This is necessary if your schema can't be completely dumped by the schema dumper,
  # like if you have constraints or database-specific column types
  # config.active_record.schema_format = :sql

  # Activate observers that should always be running
  # config.active_record.observers = :cacher, :garbage_collector

  config.reload_plugins = true if RAILS_ENV == 'development'

end

ActiveRecord::ConnectionAdapters::MysqlAdapter::NATIVE_DATABASE_TYPES[:primary_key] = "BIGINT UNSIGNED DEFAULT NULL auto_increment PRIMARY KEY"


