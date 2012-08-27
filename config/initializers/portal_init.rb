# require 'portal/liquid/random'
require 'portal/portal_view'

if defined? ActionView::Template and ActionView::Template.respond_to? :register_template_handler
  ActionView::Template
else
  ActionView::Base
end.register_template_handler(:portal, PortalView)

# Liquid::Template.register_tag('random', Random)

# Portal.liquid_tags.each { |name, klass| Liquid::Template.register_tag name, klass }

puts "=> Setting support portal view template"