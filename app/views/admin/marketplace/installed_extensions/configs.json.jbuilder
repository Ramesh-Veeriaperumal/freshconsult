if @platform_version == '2.0'
  json.configs_page @configs_page
  json.configs_url @configs_url
  json.configs @configs
else
  json.configs do
    json.array! @configs
  end
end

json.display_name display_name
json.installation_type params[:installation_type]
json.install_btn install_btn
json.extension_id params[:extension_id]
json.version_id params[:version_id]
json.features @extension['features']

# only custom (app_type == 2), backend apps are given log view
json.has_logs has_logs

json.back_url show_admin_marketplace_extensions_path(params['extension_id']) + '?' + index_url_params
json.platform_version @platform_version
