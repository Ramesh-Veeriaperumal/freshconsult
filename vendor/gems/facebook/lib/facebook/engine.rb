# Include hook code here
module Facebook
  class Engine < ::Rails::Engine
  	config.eager_load_paths += Dir["#{config.root}/lib/**/"]
  end
end
