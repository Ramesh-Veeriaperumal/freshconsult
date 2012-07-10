#require 'custom_liquid'

Dir["#{RAILS_ROOT}/lib/custom_liquid/tags/*.rb"].each { |tag| require tag }

Liquid::Template.register_tag("translate", Translate)

# class ActionController::Dispatcher
#   def self.register_liquid_tags
#     #Mephisto.liquid_filters.each { |mod| Liquid::Template.register_filter mod }
# 	begin
#     	#@liquid_tags.each { |name, klass| Liquid::Template.register_tag name, klass }
#     	liquid_tags
#     rescue
#     	puts "Error #{$!}"
#   end
# end

#ActionController::Dispatcher.register_liquid_tags