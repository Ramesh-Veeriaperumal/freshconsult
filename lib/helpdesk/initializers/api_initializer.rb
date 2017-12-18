$infra = YAML.load_file(File.join(Rails.root, 'config', 'infra_layer.yml'))

if $infra['API_LAYER']
  Helpkit::Application.configure do
    config.middleware.delete 'Middleware::ApiThrottler'
    config.middleware.insert_before ActionDispatch::ParamsParser, "Middleware::ApiRequestInterceptor"

    # API layer uses new verison API throttler. Hence deleted the above middleware and inserted new.
    config.middleware.insert_before 'Middleware::ApiRequestInterceptor', 'Middleware::ApiPipeAuthenticator' if $infra['PIPE_LAYER']

    if $infra['PRIVATE_API']
      config.middleware.insert_before 'Middleware::ApiRequestInterceptor', 'Middleware::PrivateApiThrottler', max: 1000
      # Basic auth should be ignored for private API. Cookie & JWT based auth will be allowed
      config.middleware.insert_before 'Middleware::ApiRequestInterceptor', 'Middleware::PrivateBasicAuth'
    else
      config.middleware.insert_before 'Middleware::ApiRequestInterceptor', 'Middleware::FdApiThrottler', max: 1000
    end

    if $infra['PIPE_LAYER']
      config.middleware.insert_before 'Middleware::ApiRequestInterceptor', 'Middleware::ApiPipeAuthenticator'
      config.middleware.use BatchApi::RackMiddleware do |batch_config|
        # you can set various configuration options:
        batch_config.verb = :post # default :post
        batch_config.endpoint = "/api/pipe/batch" # default /batch
        batch_config.limit = 20 # how many operations max per request, default 50

        # default middleware stack run for each batch request
        batch_config.batch_middleware = Proc.new { use Middleware::BatchApiRateLimiter }
        # default middleware stack run for each individual operation
        batch_config.operation_middleware = Proc.new {
          use BatchApi::InternalMiddleware::DecodeJsonBody
          use BatchApi::InternalMiddleware::DependencyResolver
          use Middleware::BatchApiRequestIdInjector
        }
      end
    end
    # This middleware will attempt to return the contents of a file's body from disk in the response.
    # If a file is not found on disk, the request will be delegated to the application stack.
    # This middleware is commonly initialized to serve assets from a server's `public/` directory.
    config.middleware.delete ActionDispatch::Static unless ($infra['PRIVATE_API'] && Rails.env == "development")

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
    config.middleware.use Middleware::ApiResponseWrapper if $infra['PRIVATE_API']

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

    # Creating Custom API Handler with ".api" extension
    module ActionView
      module Template::Handlers
        class RubyTemplate
          cattr_accessor :default_format
          self.default_format = Mime::JSON
          def self.call(template)
            template.source
          end
        end
      end
    end

    # Registering the Custom API Handler to the as one of the supported views.
    ActionView::Template.register_template_handler(:api, ActionView::Template::Handlers::RubyTemplate)

    module ActionController
      Parameters.class_eval do
      private

        # Adding array/hash also in permitted scalar to allow the key with complex values to be passed through strong params.
        # for ex: user_id:[] used to fail at strong params as [] is not a permitted scalar value.
        # Now user_id:[] will pass through strong params and corresponding data_type validation will occur in controller.
        def permitted_scalar?(value)
          (Parameters::PERMITTED_SCALAR_TYPES | [Array, Hash]).any? { |type| value.is_a?(type) }
        end
      end
    end

    # Metal changes has to be included irrespective of whether the layer is API or not.
    # This is required as in some cases, API and web requests can be served from the same box.
    ActionController::Metal.send(:include, AbstractController::Callbacks)
    ActionController::Metal.send(:include, Authlogic::ControllerAdapters::RailsAdapter::RailsImplementation)
  end

end

if $infra['PRIVATE_API']
  module ActionDispatch
    Response.class_eval do
      attr_accessor :api_meta, :api_root_key
    end
  end
end

# Fallback to dalli.yml if dalli_api.yml doesn't exist.
# This change facilitates having a new memcache cluster for API controllers and views.
file = File.join(Rails.root, 'config', 'dalli_api.yml')
file_exists = File.exist?(file)
file = File.join(Rails.root, 'config', 'dalli.yml') unless file_exists

METAL_CACHE_CONFIG = YAML.load_file(file)[Rails.env].symbolize_keys!
METAL_MEMCACHE_SERVER = METAL_CACHE_CONFIG.delete(:servers)
