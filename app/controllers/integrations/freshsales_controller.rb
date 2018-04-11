class Integrations::FreshsalesController < Admin::AdminController

  include Integrations::ControllerMethods

  before_filter :load_installed_app, :only => [:install, :edit, :update]
  before_filter :check_installed_app, :only => [:new, :settings_update]

  def new
    render_settings
  end

  def settings_update
    @installed_app = Integrations::InstalledApplication.new
    @installed_app.set_configs get_api_params
    @freshsales_config = Hash.new
    return unless verify_api_credentials
    fetch_metadata_fields
    @action = "install"
    @installed_app = nil
    render_metadata_fields
  end

  def edit
    @freshsales_config = Hash.new
    fetch_metadata_fields
    @action = "update"
    render_metadata_fields
  end

  def install
    begin
      install_or_update get_metadata_fields(params)
      flash[:notice] = t(:'flash.application.install.success')
      redirect_to integrations_applications_path
    rescue => e
      NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in installing freshsales application : #{e.message}"}})
      flash[:error] = t(:'flash.application.install.error')
      redirect_to integrations_applications_path
    end
  end

  def update
    begin
      install_or_update get_metadata_fields(params)
      flash[:notice] = t(:'flash.application.update.success')
      redirect_to integrations_applications_path
    rescue => e
      NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in updating freshsales application : #{e.message}"}})
      flash[:error] = t(:'flash.application.update.error')
      redirect_to integrations_applications_path
    end
  end

  private

  def verify_api_credentials
    begin
      @freshsales_config['contact_fields'] = service_obj.receive(:contact_fields)
      install_or_update default_configs.merge(get_api_params)
    rescue IntegrationServices::Errors::RemoteError => e
      flash.now[:error] = "#{t(:'integrations.freshsales.form.error')}"
      render_settings and return false
    rescue => e
      NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in installing freshsales application : #{e.message}"}})
      flash[:error] = t(:'flash.application.install.error')
      redirect_to integrations_applications_path and return false
    end
    true
  end

  def install_or_update config_params
    @installed_app = Integrations::Application.install_or_update(app_name,current_account.id,config_params)
  end

  def get_api_params
    { "domain" => "https://#{params["configs"]["domain"]}", "auth_token" => params["configs"]["auth_token"], "ghostvalue" => params["configs"]["ghostvalue"]  }
  end

  def render_settings
    render :template => "integrations/applications/freshsales/freshsales_settings",
           :locals => {:configs => params["configs"]},
           :layout => 'application'
  end

  def fetch_metadata_fields
    @freshsales_config['contact_fields'] ||= service_obj.receive(:contact_fields)
    @freshsales_config['lead_fields'] = service_obj.receive(:lead_fields)
    @freshsales_config['account_fields'] = service_obj.receive(:account_fields)
    @freshsales_config['deal_fields'] = service_obj.receive(:deal_fields)
  end

  def get_metadata_fields(params)
    config_hash = Hash.new 
    config_hash['contact_fields'] = params[:contacts].join(",") unless params[:contacts].nil?
    config_hash['lead_fields'] = params[:leads].join(",") unless params[:leads].nil?
    config_hash['account_fields'] = params[:accounts].join(",") unless params[:accounts].nil?
    config_hash['contact_labels'] = params['contact_labels']
    config_hash['lead_labels'] = params['lead_labels']
    config_hash['account_labels'] = params['account_labels']
    config_hash = get_deal_params config_hash
    config_hash
  end

  def get_deal_params(config_hash)
    config_hash['deal_view'] = params["deal_view"]["value"]
    if config_hash['deal_view'].to_bool
      config_hash['deal_fields'] = params[:deals].join(",") unless params[:deals].nil?
      config_hash['deal_labels'] = params['deal_labels']
      config_hash['agent_settings'] = params["agent_settings"] ? 
                                      params["agent_settings"]["value"] : 'false'

      if config_hash['agent_settings'].to_bool
        config_hash["deal_stage_choices"] = service_obj.receive(:deal_stage_choices)
      else
        @installed_app.configs[:inputs].delete("deal_stage_choices")
      end
    else
      deal_configs = [ "deal_fields", "deal_labels", "agent_settings", "deal_stage_choices" ]
      @installed_app.configs[:inputs] = @installed_app.configs[:inputs].except(*deal_configs)
    end
    config_hash
  end

  def render_metadata_fields
    render :template => "integrations/applications/freshsales/freshsales_fields",
           :layout => 'application'
  end

  def default_configs
    config_hash = Hash.new
    config_hash['contact_fields'] = "display_name"
    config_hash['account_fields'] = "name"
    config_hash['lead_fields'] = "display_name"
    config_hash['contact_labels'] = "Full name"
    config_hash['account_labels'] = "Name"
    config_hash['lead_labels'] = "Full name"
    config_hash['deal_view'] = "0"
    config_hash
  end

  def app_name
    "freshsales"
  end
end