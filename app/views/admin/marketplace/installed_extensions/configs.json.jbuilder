json.configs do
  json.array! @configs
end

json.display_name params[:display_name]
json.installation_type params[:installation_type]
json.install_btn install_btn
json.back_url show_admin_marketplace_extensions_path(params['version_id']) + '?' + index_url_params