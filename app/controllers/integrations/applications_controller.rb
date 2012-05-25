class Integrations::ApplicationsController < Admin::AdminController

  include Integrations::AppsUtil

  def index
    @applications = Integrations::Application.find(:all, :order => :listing_order)
    @installed_applications = get_installed_apps
  end

  def oauth_install
  	app_config = KeyValuePair.find_by_account_id_and_key(current_account.id, "#{params['id']}_oauth_config")
    unless app_config.blank?
	    config_hash = JSON.parse(app_config.value)
		app_name = config_hash["app_name"]
		config_hash.delete("app_name")	    
	    installed_application = Integrations::Application.install_or_update(app_name, current_account.id, config_hash)
	    flash[:notice] = t(:'flash.application.install.success') if installed_application
	    app_config.delete
	end
    redirect_to :controller=> 'applications', :action => 'index'
  end

  def show
    @installing_application = Integrations::Application.find(params[:id])
  end
end
