module TextDataStore
  class Engine < ::Rails::Engine
    config.eager_load_paths += Dir["#{config.root}/lib/**/"]
    engine_name 'text_data_store'
    initializer 'text_data_store.setup' do
      ActiveSupport.on_load :active_record do
        ActiveRecord::Base.send(:include, DataStoreCallbacks)
      end
    end
  end
end
