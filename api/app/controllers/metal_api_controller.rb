class MetalApiController < ActionController::Metal
  # Modules to be included for metal controller to work for our APP
  # Do not change the order of modules included
  include ActionController::Head # needed when calling head
  include ActionController::Helpers # needed for calling methods which are defined as helper methods.
  include ActionController::Redirecting
  include ActionController::Rendering
  include ActionController::RackDelegation # Needed so that request and response method will be delegated to Rack
  include ActionController::Caching
  include Rails.application.routes.url_helpers # Need for location header in response
  include ActiveSupport::Rescuable # Dependency with strong params
  include ActionController::MimeResponds  # Needed for respond_to/redirect_to
  include ActionController::ImplicitRender
  include ActionController::StrongParameters
  include ActionController::Cookies
  include ActionController::HttpAuthentication::Basic::ControllerMethods
  include AbstractController::Callbacks # before filters
  include ActionController::Rescue
  include ActionController::ParamsWrapper
  include ActionController::Instrumentation  # need this for active support instrumentation.

  # For configuration(like perform_caching, allow_forgery_protection) to be loaded for action controller metal, there are methods originally in base needs to be declared.
  extend MetalCompatibility

  MetalApiController.cache_store = :dalli_store, ApiConstants::METAL_MEMCACHE_SERVER, ApiConstants::METAL_CACHE_CONFIG
  # Lazy loading hooks for metal controller.
  ActiveSupport.run_load_hooks(:action_controller, self)

  # Metal controller doesn't know the view path. So appending it.
  append_view_path "#{Rails.root}/api/app/views"

  def self.wrap_params
    ApiConstants::WRAP_PARAMS
  end

  # wrap params will wrap only attr_accessible fields if this is removed.
  def self.inherited(subclass)
    subclass.wrap_parameters(*wrap_params)
  end
end
