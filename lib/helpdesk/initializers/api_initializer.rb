Helpkit::Application.configure do
  config.middleware.insert_before ActionDispatch::ParamsParser, 'Middleware::ApiRequestInterceptor'
  # API layer uses new verison API throttler
  config.middleware.insert_before 'Middleware::ApiRequestInterceptor', 'Middleware::ApiPipeAuthenticator'
  config.middleware.insert_before 'Middleware::ApiRequestInterceptor', 'Middleware::PrivateApiThrottler', max: 1000
  config.middleware.insert_before 'Middleware::ApiRequestInterceptor', 'Middleware::FdApiThrottler', max: 1000
  config.middleware.insert_before 'Middleware::ApiRequestInterceptor', 'Middleware::ChannelApiThrottler'
  config.middleware.insert_before 'Middleware::ApiRequestInterceptor', 'Middleware::WidgetApiThrottler'
  # Basic auth should be ignored for private API. Cookie & JWT based auth will be allowed
  config.middleware.insert_before 'Middleware::ApiRequestInterceptor', 'Middleware::PrivateBasicAuth'
  config.middleware.insert_before 'Middleware::TrustedIp', 'Middleware::FreshidCallbackApiAuthenticator'
  config.middleware.use Middleware::ApiResponseWrapper

  # used by freshid requests
  Freshid.user_class            = 'User'
  Freshid.account_class         = 'Account'
  Freshid.authorization_class   = 'Authorization'
  Freshid.domain_mapping_class  = 'DomainMapping'
  Freshid.events_to_track       = %w[PROFILE_UPDATED USER_ACTIVATED PASSWORD_UPDATED RESET_PASSWORD]
  Freshid::CallbackMethods.safe_send(:prepend, Freshid::CallbackMethodsExtensions)
  Freshid::ApiCalls.safe_send(:prepend, Freshid::ApiCallsExtensions)
  Freshid::SnsErrorNotification.safe_send(:prepend, Freshid::SnsErrorNotificationExtensions)
  # used by pipe requests
  config.middleware.use BatchApi::RackMiddleware do |batch_config|
    # you can set various configuration options:
    batch_config.verb = :post # default :post
    batch_config.endpoint = '/api/pipe/batch' # default /batch
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

module ActionDispatch
  Response.class_eval do
    attr_accessor :api_meta, :api_root_key
  end
end

# Fallback to dalli.yml if dalli_api.yml doesn't exist.
# This change facilitates having a new memcache cluster for API controllers and views.
file = File.join(Rails.root, 'config', 'dalli_api.yml')
file_exists = File.exist?(file)
file = File.join(Rails.root, 'config', 'dalli.yml') unless file_exists

METAL_CACHE_CONFIG = YAML.load_file(file)[Rails.env].symbolize_keys!
METAL_MEMCACHE_SERVER = METAL_CACHE_CONFIG.delete(:servers)
