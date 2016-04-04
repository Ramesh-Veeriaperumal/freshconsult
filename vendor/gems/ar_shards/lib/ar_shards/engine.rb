# require 'acts_as_voteable'
# ActiveRecord::Base.send(:include, Juixe::Acts::Voteable)
module ArShards
  class Engine < ::Rails::Engine
    config.eager_load_paths += Dir["#{config.root}/lib/**/"]
  end
end
