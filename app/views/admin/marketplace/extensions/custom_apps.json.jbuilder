json.app_gallery_url custom_apps_admin_marketplace_extensions_path

json.extensions @extensions do |extension|
  json.merge! extension
  json.url show_admin_marketplace_extensions_path(extension['id']) + '?' + { type: extension['type'] }.to_query
  json.pricing pricing_state(extension)
end

json.custom_app true
