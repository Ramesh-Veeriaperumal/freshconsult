module Admin::Marketplace::InstalledExtensionsHelper
  include Admin::Marketplace::CommonHelper

  def install_btn
    if params[:installation_type] == 'install'
      {
        :url => admin_marketplace_installed_extensions_install_path(params[:extension_id], params[:version_id]),
        :method => :post,
        :text => t('marketplace.install')
      }
    else
      {
        :url => admin_marketplace_installed_extensions_reinstall_path(params[:extension_id], params[:version_id]),
        :method => :put,
        :text => params[:installation_type] == 'update' ? t('marketplace.update') : t('save')
      }
    end
  end
end
