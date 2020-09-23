class Integrations::ApplicationsController < Admin::AdminController
  include Integrations::AppsUtil
  include Integrations::OauthHelper
  include Marketplace::ApiHelper
  
  before_filter { |c| c.requires_feature :marketplace }
  before_filter :load_object, :only => [:show]
  
  def index
    return if current_account.marketplace_gallery_enabled?

    if current_account.native_apps_enabled?
      @applications = Integrations::Application.available_apps(current_account)
      @installed_applications = get_installed_apps
    else
      installed_extensions = installed_mkp_apps(:integrations_list)
      @installed_mkp_apps = installed_extensions[:installed_mkp_apps]
      @installed_custom_apps = installed_extensions[:installed_custom_apps] if current_account.custom_apps_enabled?
    end

    @custom_applications = Integrations::Application.freshplugs(current_account)
  end

  def oauth_install
    key_options = { :account_id => current_account.id, :provider => params['id']}
    kv_store = Redis::KeyValueStore.new(Redis::KeySpec.new(Redis::RedisKeys::APPS_AUTH_REDIRECT_OAUTH, key_options))
    kv_store.group = :integration
    app_config = kv_store.get_key
    if app_config.blank?
      Rails.logger.debug "Refresh Access token as this is Edit ::#{params['id']}"
      @installed_app = Integrations::InstalledApplication.includes(:application).where(["#{Integrations::Application.table_name}.name = ? and  #{Integrations::InstalledApplication.table_name}.account_id = ?", params['id'], current_account]).first
       #added for edit option as there won't be any redis store while editing.
      access_token = get_oauth2_access_token(@installed_app.application.oauth_provider, @installed_app.configs[:inputs]['refresh_token'],params['id']) 
      oauth_token= access_token.token
      @installed_app[:configs][:inputs]['oauth_token'] = access_token.token
      @installed_app.save #updating the installed app with new token
      app_config = @installed_app.configs[:inputs].to_json if @installed_app.application.options[:pre_install]
    end
  	begin
  		unless app_config.blank?
  		  config_hash = JSON.parse(app_config)
  			app_name = config_hash["app_name"]
  			config_hash.delete("app_name")	    
        app_name = params['id'] if app_name.blank?
		    installed_application = Integrations::Application.install_or_update(app_name, current_account.id, config_hash)
		    flash[:notice] = t(:'flash.application.install.success') if installed_application
		    kv_store.remove_key
        if (installed_application.application.name == Integrations::Constants::APP_NAMES[:quickbooks])
          redirect_to integrations_quickbooks_render_success_path and return
        end
        if(installed_application.application.options[:configurable])
          redirect_to edit_integrations_installed_application_path(installed_application)
          return
        end
	    end	
  	rescue Exception => msg
      Rails.logger.debug "Something went wrong while configuring an installed application ( #{msg})"
      Rails.logger.debug msg.backtrace.join("\n") #added trace as we need logs on exception!!!
      flash[:error] = t(:'flash.application.install.error')
  	end
    redirect_to :controller=> 'applications', :action => 'index'
  end

  def show
    if @installing_application.name == Integrations::Constants::APP_NAMES[:shopify]
      render "integrations/applications/shopify/add_store"
    end
  end

  private
    def load_object
     @installing_application = Integrations::Application.available_apps(current_account).find(params[:id])
    end

end
