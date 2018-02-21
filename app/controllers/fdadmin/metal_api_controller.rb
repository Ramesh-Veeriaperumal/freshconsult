class Fdadmin::MetalApiController < ActionController::Metal

  extend Compatibility

  ApiConstants::METAL_MODULES.each do |metal_lib|
    safe_send(:include,metal_lib)
  end
  
  ActiveSupport.run_load_hooks(:action_controller, self)  
end
