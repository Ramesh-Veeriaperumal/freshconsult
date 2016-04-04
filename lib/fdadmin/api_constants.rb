module Fdadmin::ApiConstants
  
  METAL_MODULES = [ 
    ActionController::Head,
    ActionController::Helpers, # needed for calling methods which are defined as helper methods.
    AbstractController::Rendering,
    ActionController::Renderers::All,
    ActionController::RackDelegation,  # Needed so that request and response method will be delegated to Rack
    ActionController::MimeResponds,
    AbstractController::Callbacks,
    ActionController::Rescue,
    ActionController::ParamsWrapper,
    ActionController::Instrumentation  # need this for active support instrumentation.
  ]

end