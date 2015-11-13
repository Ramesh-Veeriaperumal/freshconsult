Infra = YAML.load_file(File.join(Rails.root, 'config', 'infra_layer.yml'))

if Infra['API_LAYER']
  Helpkit::Application.configure do

    config.middleware.swap "Middleware::ApiThrottler", "Middleware::FdApiThrottler", :max => 1000

    # This middleware will attempt to return the contents of a file's body from disk in the response. 
    # If a file is not found on disk, the request will be delegated to the application stack. 
    # This middleware is commonly initialized to serve assets from a server's `public/` directory.
    config.middleware.delete ActionDispatch::Static 

    # Adds response time header to response.
    config.middleware.delete Rack::Runtime

    # Callbacks for each request.
    config.middleware.delete ActionDispatch::Callbacks

    # Flash
    config.middleware.delete ActionDispatch::Flash

    # We are not allowing HEAD for CORS.
    config.middleware.delete ActionDispatch::Head

    # https://github.com/rack/rack/blob/master/lib/rack/conditionalget.rb
    # env['HTTP_IF_MODIFIED_SINCE'] or env['HTTP_IF_NONE_MATCH'] should be present in response headers, for this to work.
    config.middleware.delete Rack::ConditionalGet 

    # set_cache_buster sets "no-cache" header, which makes this middleware superfluous. 
    # Refer to https://github.com/rack/rack/blob/master/lib/rack/etag.rb for rationale.
    config.middleware.delete Rack::ETag
    
    # sets X-UA-Compatible header, used by browsers.
    config.middleware.delete ActionDispatch::BestStandardsSupport

    # Authentication
    config.middleware.delete OpenIdAuthentication

    # Authentication
    config.middleware.delete OmniAuth::Builder

    # A gem which helps you detect the users preferred language, 
    # as sent by the "Accept-Language" HTTP header. Used only in account create.
    config.middleware.delete HttpAcceptLanguage::Middleware
 
    # Deep_munge has to be patched as it converts empty array to nil
    # https://github.com/rails/rails/issues/13420
    module ActionDispatch
      Request.class_eval do

        # Remove nils from the params hash
        # https://github.com/rails/rails/blob/50d6b4549d56ac3a82f2096bd479a7b2305b0bf3/actionpack/lib/action_dispatch/http/request.rb#L257
        def deep_munge(hash)
          hash.each do |k, v|
            case v
            when Array
              v.grep(Hash) { |x| deep_munge(x) }
              v.compact!
              hash[k] = v if v.empty? # Assign empty array instead of nil if it's value is empty?
            when Hash
              deep_munge(v)
            end
          end
          hash
        end

      end
    end

  end

end

# Fallback to dalli.yml if dalli_api.yml doesn't exist. 
# This change facilitates having a new memcache cluster for API controllers and views.
file = File.join(Rails.root, 'config', 'dalli_api.yml')
file_exists = File.exists?(file)
file = File.join(Rails.root, 'config', 'dalli.yml') unless file_exists

METAL_CACHE_CONFIG = YAML.load_file(file)[Rails.env].symbolize_keys!
METAL_MEMCACHE_SERVER = METAL_CACHE_CONFIG.delete(:servers)

# Metal changes has to be included irrespective of whether the layer is API or not. 
# This is required as in some cases, API and web requests can be served from the same box.
ActionController::Metal.send(:include, AbstractController::Callbacks )
ActionController::Metal.send(:include, Authlogic::ControllerAdapters::RailsAdapter::RailsImplementation)