# require 'acts_as_voteable'
# ActiveRecord::Base.send(:include, Juixe::Acts::Voteable)
module HasFlexiblefields
  class Engine < ::Rails::Engine
    config.eager_load_paths += Dir["#{config.root}/lib/**/"]
    engine_name 'has_flexiblefields'

    initializer 'has_flexiblefields.setup' do
      ActiveSupport.on_load :active_record do
        ActiveRecord::Base.send :include, Has::FlexibleFields
      end
    end
  end
end
