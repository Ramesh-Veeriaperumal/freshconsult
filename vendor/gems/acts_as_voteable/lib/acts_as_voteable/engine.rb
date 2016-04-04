# require 'acts_as_voteable'
# ActiveRecord::Base.send(:include, Juixe::Acts::Voteable)
module ActsAsVoteable
  class Engine < ::Rails::Engine
    config.eager_load_paths += Dir["#{config.root}/lib/**/"]
    engine_name 'acts_as_voteable'

    initializer 'acts_as_voteable.setup' do
      ActiveSupport.on_load :active_record do
        ActiveRecord::Base.send(:include, Juixe::Acts::Voteable)
      end
    end
  end
end
