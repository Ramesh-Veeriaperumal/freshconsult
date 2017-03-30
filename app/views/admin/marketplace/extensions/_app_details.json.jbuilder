json.merge! extension
json.url show_admin_marketplace_extensions_path(extension['id']) + '?' + show_url_params
json.pricing pricing_state(extension)