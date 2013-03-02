class Integrations::ApplicationsController < Admin::AdminController

  include Integrations::AppsUtil
  include Integrations::SalesforceUtil
  before_filter :load_object, :only => [:show, :edit, :update, :destroy]
  before_filter :store_location, :only => [:index]


  def index
    @applications = Integrations::Application.available_apps(current_account).order(:listing_order)
    @installed_applications = get_installed_apps
  end

  def oauth_install
  	app_config = KeyValuePair.find_by_account_id_and_key(current_account.id, "#{params['id']}_oauth_config")
  	begin
  		unless app_config.blank?
		    config_hash = JSON.parse(app_config.value)
  			app_name = config_hash["app_name"]
  			config_hash.delete("app_name")	    
        if params['id'] == 'salesforce' 
          config_hash['contact_fields'] = fetch_sf_contact_fields(config_hash['oauth_token'], config_hash['instance_url']) 
          config_hash['lead_fields'] = fetch_sf_lead_fields(config_hash['oauth_token'], config_hash['instance_url']) 
        end
		    installed_application = Integrations::Application.install_or_update(app_name, current_account.id, config_hash)
		    flash[:notice] = t(:'flash.application.install.success') if installed_application
		    app_config.delete
	    end	
  	rescue Exception => msg
  		puts "Something went wrong while configuring an installed application ( #{msg})"
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
      wid = @installing_application.widgets[0]
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
end
