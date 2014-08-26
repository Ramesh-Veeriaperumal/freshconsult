module Xss
  class Engine < ::Rails::Engine
    config.eager_load_paths += Dir["#{config.root}/lib/**/"]
    engine_name 'xss'
    initializer 'xss.setup' do
      ActiveSupport.on_load :active_record do
        ActiveRecord::Base.send(:include, HtmlSanitizer)
      end
    end
  end
end
