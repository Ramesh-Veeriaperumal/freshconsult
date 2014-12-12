class Integrations::RemoteConfigurationsController < Admin::AdminController

  include Integrations::RemoteConfigurations::Seoshop

  skip_before_filter :check_privilege
  before_filter :authorize_freshdesk_user, :only => [ :create ]
  before_filter :validate_wrt_app, :only => [ :create ]

  APPCONFIG = YAML::load_file File.join(Rails.root, 'config', 'app_config.yml')

  def show
    partial_link
  end

  def create
    domain = params[:domain].partition('://').last
    domain_mapping = DomainMapping.find_by_domain(domain)
    if domain_mapping
      Sharding.select_shard_of(domain) do
        if(params[:app_params]["app"] == "seoshop")
          process_seoshop(domain, domain_mapping.account_id)
        end
      end
    end
  end

  def validate_wrt_app
    params[:app_params] = JSON.parse params[:app_params].gsub('=>', ':')
    if(params[:app_params]["app"] == "seoshop")
      validate_seoshop(APPCONFIG["seoshop"])
    end
  end

private
  def authorize_freshdesk_user
    # site = RestClient::Resource.new("#{params[:domain]}/ticket_fields.json", params[:key], "X")
    site = RestClient::Resource.new("#{params[:domain]}/health_status.json", params[:key], "X")
    response = site.get(:accept => "application/json")
    # if !response.body.include? "ticket_field"
    if !response.body.include? "success"
      show_notice "Unable to authorize user in Freshdesk..... Please check your domain and API Key....."
    end
  end

  def install_application(domain, account_id)
    app = Integrations::Application.find_by_name(params[:app_params]["app"])
    ia = Integrations::InstalledApplication.find(:all, :conditions => {:application_id => app.id, :account_id => account_id})
    if(ia.nil? || ia.empty?)
      new_app = Integrations::InstalledApplication.new
      new_app.application_id = app.id
      new_app.account_id = account_id
      new_app.configs = build_configs
      new_app.save!
      flash[:notice] = "Application is successfully installed in this domain"
      redirect_to redirect_url
      
    else
      show_notice "Application is already installed for this domain"
    end
  end

  def build_configs
    if(params[:app_params]["app"] == "seoshop")
      build_seoshop_configs(APPCONFIG["seoshop"])
    end
  end

  def uninstall_application(domain, account_id)
    app = Integrations::Application.find_by_name(params[:app_params]["app"])
    installed_app = Integrations::InstalledApplication.find(:all, :conditions => {:application_id => app.id, :account_id => account_id})[0]
    if(installed_app.nil?)
      show_notice "Application is not installed in this Domain!"
    else
      if installed_app.destroy
        flash[:notice] = "Application is successfully uninstalled in this domain"
        redirect_to redirect_url
      else
        show_notice "Application uninstall failed"
      end
    end
  end

  def show_notice(message)
    flash.now[:notice] = message
    partial_link
  end

  def redirect_url
    if(params[:app_params]["app"] == "seoshop")
      "#{params[:domain]}/helpdesk/dashboard"
    end
  end

  def partial_link
    render :partial => "integrations/applications/remote_login", :locals => {:page => "seoshop"}, :layout => 'remote_configurations'
  end
end