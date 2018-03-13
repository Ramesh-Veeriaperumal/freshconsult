module Admin::Marketplace::InstalledExtensionsHelper
  include Admin::Marketplace::CommonHelper

  def has_logs
    @extension['features'].include?('backend') && (@extension['app_type'] == 2 || @extension['type'] == 6) && params[:action] == 'edit_configs'
  end

  def install_btn
    params_hash = params[:version_id] ? { version_id: params[:version_id] } : {}
    query_params = params_hash.blank? ? '' : "?#{params_hash.to_query}"
    if params[:installation_type] == 'install'
      return oauth_iparams_continue_btn if params[:page] == 'oauth_iparams'
      {
        :url => admin_marketplace_installed_extensions_install_path(params[:extension_id])+query_params,
        :method => :post,
        :text => t('marketplace.install'),
        :install_button => 'install-btn'
      }
    else
      params_hash[:installed_version] = params[:installed_version] if params[:installed_version]
      params_hash[:upgrade] = true if params[:is_oauth_app]
      query_params = "?#{params_hash.to_query}"
      if params[:installation_type] == 'settings'
        return oauth_iparams_reauthorize_btn if params[:page] == 'oauth_iparams'
        url = admin_marketplace_installed_extensions_update_config_path(params[:extension_id])
      else 
        url = admin_marketplace_installed_extensions_reinstall_path(params[:extension_id])
      end
      {
        :url => "#{url}#{query_params}",
        :method => :put,
        :text => params[:installation_type] == 'update' ? t('marketplace.update') : t('save'),
        :is_oauth_app => params[:is_oauth_app],
        :install_button => 'install-btn'
      }
    end
  end

  # when install, show continue button.
  def oauth_iparams_continue_btn
    {
      :url => admin_marketplace_installed_extensions_oauth_install_path(params[:extension_id], params[:version_id]),
      :text => t('marketplace.oauth_install_continue'),
      :page => params[:page],
      :install_button => 'install-oauth-btn'
    }
  end
  
  # when edit oauth iparams, show reauthorize button.
  def oauth_iparams_reauthorize_btn
    {
      :url => admin_marketplace_installed_extensions_edit_oauth_configs_path(params[:extension_id], params[:version_id]),
      :method => :put,
      :text => t('marketplace.reauthorize').upcase,
      :page => params[:page],
      :install_button => 'install-oauth-btn'
    }
  end
end
