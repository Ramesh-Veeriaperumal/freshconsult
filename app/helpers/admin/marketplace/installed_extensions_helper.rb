module Admin::Marketplace::InstalledExtensionsHelper
  include Admin::Marketplace::CommonHelper

  def install_btn
    params_hash = params[:version_id] ? { version_id: params[:version_id] } : {}
    query_params = params_hash.blank? ? '' : "?#{params_hash.to_query}"
    if params[:installation_type] == 'install'
      {
        :url => admin_marketplace_installed_extensions_install_path(params[:extension_id])+query_params,
        :method => :post,
        :text => t('marketplace.install')
      }
    else
      {
        :url => admin_marketplace_installed_extensions_reinstall_path(params[:extension_id])+query_params,
        :method => :put,
        :text => params[:installation_type] == 'update' ? t('marketplace.update') : t('save')
      }
    end
  end
end
