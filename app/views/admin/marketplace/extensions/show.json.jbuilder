json.merge! @extension.except('categories')

json.categories @extension['categories'] do |category|
  json.extract! category, 'name'
  json.url category_url(category)
end

json.search_url search_admin_marketplace_extensions_path + "?type=#{params['type']}"
json.search_placeholder search_placeholder
json.search_term params[:query]
json.auto_suggest_url auto_suggest_admin_marketplace_extensions_path + "?type=#{params['type']}"
json.category_name category_name(@extension['categories'])
json.category_id params['category_id']
json.back_url custom_app? ? custom_apps_admin_marketplace_extensions_path : admin_marketplace_extensions_path + '?' + app_gallery_params
json.back_categ_url custom_app? ? custom_apps_admin_marketplace_extensions_path : admin_marketplace_extensions_path + '?' + show_url_params
json.install_btn install_btn(@extension, @install_status, @is_oauth_app)

if custom_app?
	json.custom_app true
end

if !custom_app? && third_party_developer?
  json.policy true
end
