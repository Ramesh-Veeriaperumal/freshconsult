require 'rails'

module WillFilter
  class Railtie < Rails::Railtie
    ["../../lib/core_ext/**",
     "../../lib/wf",
     "../../lib/wf/containers"].each do |dir|
        Dir[File.expand_path("#{File.dirname(__FILE__)}/#{dir}/*.rb")].sort.each do |file|
          require_or_load file
        end
    end
  end
end