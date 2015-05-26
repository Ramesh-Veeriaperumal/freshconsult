class << ActionController::Metal

  METAL_CONFIG = YAML::load_file(File.join(Rails.root, "config", "action_controller_metal.yml"))[Rails.env]

  def set_metal_config
    self.perform_caching = METAL_CONFIG["cache"]
    self.allow_forgery_protection = METAL_CONFIG["protect"]
  end
end