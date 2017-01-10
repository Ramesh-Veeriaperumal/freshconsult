require 'rack/cors'

class Middleware::CorsEnabler < Rack::Cors
  include Redis::RedisKeys
  include Redis::OthersRedis

  CORS_RESOURCE_CONFIG = {
    :headers => :any,
    :methods => [:get, :post, :put, :delete, :options], 
    :max_age => 86400, #allows client to cache preflight request for 24 hours
    #http://stackoverflow.com/questions/25673089/why-is-access-control-expose-headers-needed
    :expose => ['X-Path', 'X-Method', 'X-Query-String', 'X-Ua-Compatible', 'X-Meta-Request-Version', 'X-Request-Id', 'X-Runtime', 'X-RateLimit-Total', 'X-RateLimit-Remaining', 'X-RateLimit-Used-CurrentRequest', 'X-Freshdesk-API-Version'] 
    # Should have all the custom headers that server will send else your client will not have access to those headers
  }

  RESOURCE_PATH_REGEX = /\/.+(\.json|xml|\?(format=json|xml)|(.+)format=json|xml(.+))/

  def initialize(app, options = {})
    super(app, options)
    @app = app
  end

  # @all_resources is not initialized again for new request in super class. Hence empty array.
  def allow(&block)
    @all_resources = [] 
    super(&block)
  end

  def call(env)
    unless(env['HTTP_ORIGIN'])
      @status, @headers, @response = @app.call(env)
    else 
      path_regex = api_request?(env) ? env["PATH_INFO"] : RESOURCE_PATH_REGEX

      cors_resource_config_clone = CORS_RESOURCE_CONFIG.dup
      if new_api_request?(env)  
        cors_resource_config_clone[:credentials] = false if redis_key_exists?(CROSS_DOMAIN_API_GET_DISABLED)
      end
      allow do 
        origins '*'
        resource path_regex, cors_resource_config_clone
      end
      @status, @headers, @response = super(env)
    end
    [@status, @headers, @response]
  end

  # this is to allow api request with the format being sent in query string
  # Allow V2 api requests also.
  def api_request?(env)
     new_api_request?(env) || env["ORIGINAL_FULLPATH"] =~ RESOURCE_PATH_REGEX 
  end

  def new_api_request?(env)
    env['PATH_INFO'].starts_with?('/api/')
  end
end
