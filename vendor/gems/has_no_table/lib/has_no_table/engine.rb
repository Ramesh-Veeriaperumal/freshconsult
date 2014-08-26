module HasNoTable
  class Engine < ::Rails::Engine
    config.eager_load_paths += Dir["#{config.root}/lib/**/"]
    engine_name 'has_no_table'
    initializer 'has_no_table.setup' do
      ActiveSupport.on_load :active_record do
        ActiveRecord::Base.send(:include, HasNoTable)
      end
    end
  end
end
