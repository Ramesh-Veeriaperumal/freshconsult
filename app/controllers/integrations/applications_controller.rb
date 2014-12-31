class Integrations::ApplicationsController < Admin::AdminController

  include Integrations::AppsUtil
  include Integrations::SalesforceUtil
  include Integrations::OauthHelper
  
  before_filter :load_object, :only => [:show]
  before_filter :load_installed_application, :only => [:edit, :update, :destroy]
  def index
    @applications = Integrations::Application.available_apps(current_account)
    @installed_applications = get_installed_apps
  end

  def oauth_install
    key_options = { :account_id => current_account.id, :provider => params['id']}
    kv_store = Redis::KeyValueStore.new(Redis::KeySpec.new(Redis::RedisKeys::APPS_AUTH_REDIRECT_OAUTH, key_options))
    kv_store.group = :integration
    app_config = kv_store.get_key
    if app_config.blank?
      Rails.logger.debug "Refresh Access token as this is Edit ::#{params['id']}"
      @installed_app = Integrations::InstalledApplication.find(:first, :include=>:application, :conditions => ["#{Integrations::Application.table_name}.name = ? and  #{Integrations::InstalledApplication.table_name}.account_id = ?",params['id'],current_account])
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
        if params['id'] == 'salesforce' 
          if params[:install].blank?
            @salesforce_config=Hash.new
            @salesforce_config['contact_fields'] = fetch_sf_contact_fields(config_hash['oauth_token'], config_hash['instance_url']) 
            @salesforce_config['lead_fields'] = fetch_sf_lead_fields(config_hash['oauth_token'], config_hash['instance_url']) 
            @salesforce_config['account_fields'] = fetch_sf_account_fields(config_hash['oauth_token'], config_hash['instance_url']) 
            render :template => "integrations/applications/salesforce_fields", :layout => ( request.headers['X-PJAX'] ? 'maincontent' : 'application' ) and return
          else
            config_hash['contact_fields'] = params[:contacts].join(",") unless params[:contacts].nil?
            config_hash['lead_fields'] = params[:leads].join(",") unless params[:leads].nil?
            config_hash['account_fields'] = params[:accounts].join(",") unless params[:accounts].nil?
            config_hash['contact_labels'] = params['contact_labels']
            config_hash['lead_labels'] = params['lead_labels']
            config_hash['account_labels'] = params['account_labels']
          end
        end
		    installed_application = Integrations::Application.install_or_update(app_name, current_account.id, config_hash)
		    flash[:notice] = t(:'flash.application.install.success') if installed_application
		    kv_store.remove_key
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

  def new
    @application = Integrations::Application.example_app
  end

  def destroy
    @installing_application.destroy
    redirect_to :controller=> 'applications', :action => 'index'
  end

  def update
    application_params = params[:application]
    unless application_params.blank?
      widget_script = application_params.delete(:script)
      view_pages = application_params.delete(:view_pages)
      @installing_application.update_attributes(application_params)
      wid = @installing_application.custom_widget
      wid.script = widget_script
      wid.display_in_pages_option = view_pages
      wid.save!
      flash[:notice] = t(:'flash.application.update.success')
    end
    redirect_to :controller=> 'applications', :action => 'index'
  end

  def create
    application_params = params[:application]
    unless application_params.blank?
      widget_script = application_params.delete(:script)
      view_pages = application_params.delete(:view_pages)
      Integrations::Application.create_and_install(application_params, widget_script, view_pages, current_account)
      flash[:notice] = t(:'flash.application.install.success')   
    end
    redirect_to :controller=> 'applications', :action => 'index'
  end

  def custom_widget_preview
    render :partial => "/integrations/widgets/custom_widget_preview", :locals => {:params=>params}
  end

  private
    def load_object
     @installing_application = Integrations::Application.available_apps(current_account).find(params[:id])
    end

    def load_installed_application
     @installing_application = Integrations::Application.freshplugs_apps(current_account).find(params[:id])
    end
end
