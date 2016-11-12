json.merge! @extension.except('categories')

json.categories @extension['categories'] do |category|
  json.extract! category, 'name'
  json.url category_url(category)
end

json.back_url custom_app? ? custom_apps_admin_marketplace_extensions_path : admin_marketplace_extensions_path + '?' + index_url_params
json.install_btn install_btn(@extension, @install_status, @is_oauth_app)

if custom_app?
	json.custom_app true
end

if !custom_app? && third_party_developer?
  json.policy true
end
