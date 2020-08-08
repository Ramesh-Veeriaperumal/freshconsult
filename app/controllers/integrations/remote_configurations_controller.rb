class Integrations::RemoteConfigurationsController < Admin::AdminController

  include Integrations::RemoteConfigurations::Seoshop

  skip_before_filter :check_privilege
  before_filter :authorize_freshdesk_user, :only => [ :create ]
  before_filter :validate_wrt_app, :only => [ :show ]


  def show
    if(params[:app] == "seoshop")
      params[:app_params] = set_seoshop_params
    end
    partial_link params[:app]
  end

  def create
    domain = params[:domain].partition('://').last.sub('/', '')
    domain_mapping = DomainMapping.find_by_domain(domain)
    if domain_mapping
      Sharding.select_shard_of(domain) do
        if(params["app"] == "seoshop")
          Account.find(domain_mapping.account_id).make_current
          process_seoshop(domain, domain_mapping.account_id)
        end
      end
    else
      show_notice "This is an invalid freshdesk domain."
    end
  end

  def validate_wrt_app
    if(params[:app] == "seoshop")
      validate_seoshop(ThirdPartyAppConfig["seoshop"])
    end
  end

private
  def authorize_freshdesk_user
    begin
      site = RestClient::Resource.new("#{params[:domain]}#{health_check_verify_credential_path}.json", params[:key], "X")
      response = site.get(:accept => "application/json")
      if !response.body.include? "success"
        show_notice "Unable to authorize user in Freshdesk..... Please check your domain and API Key....."
        logger.debug "#{params[:app]} Error::Unable to authorize user in Freshdesk..... Please check your domain and API Key....."
      end
    rescue Exception => exe
      logger.debug "#{params[:app]} Error::Exception with authorize_freshdesk_user #{exe}"
      show_notice "Unable to authorize freshdesk user"
    end
  end

  def install_application(domain, account_id)
    app = Integrations::Application.find_by_name(params[:app])
    ia = Integrations::InstalledApplication.where(application_id: app.id, account_id: account_id)
    if(ia.nil? || ia.empty?)
      new_app = Integrations::InstalledApplication.new
      new_app.application_id = app.id
      new_app.account_id = account_id
      new_app.configs = build_configs
      if new_app.save
        flash[:notice] = "Application is successfully installed in this domain"
        redirect_to redirect_url
      else
        logger.debug "#{params[:app]} Error::Application install failed."
        show_notice "Application install failed. Contact support@freshdesk.com"
      end
    else
      show_notice "Application is already installed for this domain"
    end
  end

  def build_configs
    if(params[:app] == "seoshop")
      build_seoshop_configs(ThirdPartyAppConfig["seoshop"])
    end
  end

  def uninstall_application(domain, account_id)
    app = Integrations::Application.find_by_name(params[:app])
    installed_app = Integrations::InstalledApplication.where(application_id: app.id, account_id: account_id)[0]
    if(installed_app.nil?)
      show_notice "Application is not installed in this Domain!"
    else
      if installed_app.destroy
        flash[:notice] = "Application is successfully uninstalled in this domain"
        redirect_to redirect_url
      else
        logger.debug "#{params[:app]} Error::Application uninstall failed."
        show_notice "Application uninstall failed. Contact support@freshdesk.com"
      end
    end
  end

  def show_notice(message)
    flash.now[:notice] = message
    partial_link params[:app]
  end

  def redirect_url
    if(params[:app] == "seoshop")
      "#{params[:domain]}/helpdesk"
    end
  end

  def partial_link(app)
    render :template => "integrations/applications/remote_login", :locals => {:page => app}, :layout => 'remote_configurations'
  end

  def determine_pod
    if params[:domain]
      domain = params[:domain].partition('://').last.sub('/', '')
      shard = ShardMapping.lookup_with_domain(domain)
      if PodConfig['CURRENT_POD'] != shard.pod_info
        Rails.logger.error "Current POD #{PodConfig['CURRENT_POD']}"
        redirect_to_pod(shard) and return #defined in application_controller
      end
    else
      super #fallback to the default if domain is not defined
    end
  end
end