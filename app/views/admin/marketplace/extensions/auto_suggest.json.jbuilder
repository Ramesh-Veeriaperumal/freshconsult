json.array! @auto_suggestions do |suggestions|
  json.show_url show_admin_marketplace_extensions_path(suggestions['version_id']) + '?' + index_url_params
  json.suggest_term suggestions['suggest_term']
end