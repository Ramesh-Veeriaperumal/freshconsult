require 'portal/portal_view'
require 'portal/tags/translate'
require 'portal/tags/snippet'
require 'portal/tags/paginate'

ActionView::Template.register_template_handler(:portal, PortalView)

Liquid::Template.register_tag('translate', Portal::Tags::Translate)
Liquid::Template.register_tag('snippet', Portal::Tags::Snippet)
Liquid::Template.register_tag('paginate', Portal::Tags::Paginate)

Liquid::Template.register_filter Liquid::Filters::LiquidI18nRails

# Portal.liquid_tags.each { |name, klass| Liquid::Template.register_tag name, klass }

puts "=> Setting support portal view template"