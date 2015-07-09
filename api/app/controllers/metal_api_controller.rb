class MetalApiController < ActionController::Metal
  # Modules to be included for metal controller to work for our APP

  METAL_MODULES = [ # Do not change the order of modules included
    ActionController::Head, # needed when calling head
    ActionController::Helpers, # needed for calling methods which are defined as helper methods.
    ActionController::Redirecting,
    ActionController::Rendering,
    ActionController::RackDelegation,  # Needed so that reqeest and response method will be delegated to Rack
    ActionController::Caching,
    Rails.application.routes.url_helpers, # Need for location header in response
    ActiveSupport::Rescuable, # Dependency with strong params
    ActionController::MimeResponds,
    ActionController::ImplicitRender,
    ActionController::StrongParameters,
    ActionController::Cookies,
    ActionController::HttpAuthentication::Basic::ControllerMethods,
    AbstractController::Callbacks,
    ActionController::Rescue,
    ActionController::ParamsWrapper,
    ActionController::Instrumentation  # need this for active support instrumentation.
  ]

  METAL_MODULES.each do |x|
    send(:include, x)
  end

  # For configuration(like perform_caching, allow_forgery_protection) to be loaded for action controller metal, there are methods originally in base needs to be declared.
  extend Compatibility

  # Lazy loading hooks for metal controller.
  ActiveSupport.run_load_hooks(:action_controller, self)

  # Metal controller doesn't know the view path. So appending it.
  append_view_path "#{Rails.root}/api/app/views"

  # wrap params will wrap only attr_accessible fields if this is removed.
  def self.inherited(subclass)
    subclass.wrap_parameters exclude: []
  end
end
