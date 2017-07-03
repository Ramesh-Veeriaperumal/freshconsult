json.configs do
  json.array! @configs
end

json.display_name display_name
json.installation_type params[:installation_type]
json.install_btn install_btn
json.extension_id params[:extension_id]
json.back_url show_admin_marketplace_extensions_path(params['extension_id']) + '?' + index_url_params
