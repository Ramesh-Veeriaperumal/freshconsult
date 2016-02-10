module Integrations::Marketplace::RedirectUrlHelper

  def quickbooks_url
    redirect_url = Account.current.full_url
    installed_app = Account.current.installed_applications.with_name('quickbooks').first
    if params['operation'] == 'disconnect' && installed_app.present?
      redirect_url += uninstall_integrations_installed_application_path(installed_app)
    elsif params['operation'] == 'launch' || installed_app.present?
      redirect_url += "/helpdesk"
    else
      redirect_url += "/auth/quickbooks?origin=id%3D" + Account.current.id.to_s
    end
    redirect_url
  end

  def shopify_url
    redirect_url = Account.current.full_url
    redirect_url += integrations_marketplace_shopify_landing_path + "?shop=#{@remote_id.to_s}"
    redirect_url
  end

end