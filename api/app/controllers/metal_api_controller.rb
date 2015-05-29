class MetalApiController < ActionController::Metal
  # Modules to be included for metal controller to work for our APP
  ApiConstants::METAL_MODULES.each do |x|
    send(:include, x)
  end

  # For configuration(like perform_caching, allow_forgery_protection) to be loaded for action controller metal, there are methods originally in base needs to be declared.
  extend Compatibility

  # Lazy loading hooks metal controller.
  ActiveSupport.run_load_hooks(:action_controller, self)

  # Metal controller doesn't know the view path. So appending it.
  append_view_path "#{Rails.root}/api/app/views"

  # wrap params will wrap only attr_accessible fields if this is removed.
  def self.inherited(subclass)
    subclass.wrap_parameters exclude: []
  end
end
