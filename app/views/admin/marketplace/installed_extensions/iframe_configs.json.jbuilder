json.iframe_url @iframe_url
json.display_name params[:display_name]
json.installation_type params[:installation_type]
json.back_url show_admin_marketplace_extensions_path(params['extension_id']) + '?' + index_url_params