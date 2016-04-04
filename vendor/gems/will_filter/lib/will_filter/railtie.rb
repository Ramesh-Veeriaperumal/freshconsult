require 'rails'
["../../lib/core_ext/**",
 "../../lib/wf",
 "../../lib/wf/containers"].each do |dir|
    Dir[File.expand_path("#{File.dirname(__FILE__)}/#{dir}/*.rb")].sort.each do |file|
      require_or_load file
    end
end

module WillFilter
  class Railtie < Rails::Railtie

    initializer 'will_filter' do |app|
      ActiveSupport.on_load(:action_view) do
        ApplicationHelper.send(:include, Wf::HelperMethods)
      end     
    end
  end
end