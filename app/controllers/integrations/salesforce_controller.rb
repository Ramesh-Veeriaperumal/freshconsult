class Integrations::SalesforceController < Admin::AdminController

  before_filter :load_app
  before_filter :load_installed_app, :only => [:edit, :update]
  APP_NAME = Integrations::Constants::APP_NAMES[:salesforce]


  def new
    @installed_app = current_account.installed_applications.build(:application => @application)
    @installed_app.configs = { :inputs => {} }
    @installed_app.configs[:inputs] = get_app_configs
    #redirect here to the clould elements oauth action
    if current_account.features?(:cloud_elements_crm_sync)
      set_metadata_in_redis
      redirect_to "/integrations/cloud_elements/oauth_url?state=sfdc" and return
    end
    @salesforce_config = fetch_metadata_fields
    @action = 'install'
    @installed_app = nil
    render :template => "integrations/applications/salesforce_fields"
  rescue => e
    NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in installing salesforce application : #{e.message}"}})
    flash[:error] = t(:'flash.application.install.error')
    redirect_to integrations_applications_path
  end

  def install
    begin
      @installed_app = current_account.installed_applications.build(:application => @application)
      @installed_app.configs = { :inputs => {} }
      @installed_app.configs[:inputs] = get_app_configs
      @installed_app.set_configs get_metadata_fields(params)
      @installed_app.save!
      if current_account.features?(:salesforce_sync) && salesforce_sync_option?
        service_obj.receive(:install)
      end
      flash[:notice] = t(:'flash.application.install.success')
      redirect_to integrations_applications_path
    rescue => e
      NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in installing salesforce application : #{e.message}"}})
      flash[:error] = t(:'flash.application.install.error')
      redirect_to integrations_applications_path
    end
  end

  def edit
    if current_account.features?(:cloud_elements_crm_sync)
      fetch_metadata_fields
      redirect_to "/integrations/cloud_elements/crm/edit" and return
    end
    @salesforce_config = fetch_metadata_fields
    @action = 'update'
    render :template => "integrations/applications/salesforce_fields"
  rescue => e
    NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in installing salesforce application : #{e.message}"}})
    flash[:error] = t(:'flash.application.install.error')
    redirect_to integrations_applications_path
  end

  def update
    @installed_app.set_configs get_metadata_fields(params)
    @installed_app.save!
    if current_account.features?(:salesforce_sync)
      va_rules = @installed_app.va_rules
      if salesforce_sync_option? && va_rules.blank?
        service_obj.receive(:install)
      elsif va_rules.present?
        va_rules.each do |v_r|
          v_r.update_attribute(:active,salesforce_sync_option?) 
        end
      end
    else
      va_rules = @installed_app.va_rules
      va_rules.each do |v_r|
          v_r.update_attribute(:active, false) 
      end
    end
    flash[:notice] = t(:'flash.application.update.success')
    redirect_to integrations_applications_path
    rescue => e
      NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in installing salesforce application : #{e.message}"}})
      flash[:error] = t(:'flash.application.update.error')
      redirect_to integrations_applications_path
  end

  private

  def get_metadata_fields(params)
    config_hash = Hash.new 
    config_hash['contact_fields'] = params[:contacts].join(",") unless params[:contacts].nil?
    config_hash['lead_fields'] = params[:leads].join(",") unless params[:leads].nil?
    config_hash['account_fields'] = params[:accounts].join(",") unless params[:accounts].nil?
    config_hash['contact_labels'] = params['contact_labels']
    config_hash['lead_labels'] = params['lead_labels']
    config_hash['account_labels'] = params['account_labels']
    config_hash = get_opportunity_params config_hash
    if current_account.features?(:salesforce_sync)
      config_hash['salesforce_sync_option'] = params["salesforce_sync_option"]["value"]
    end
    config_hash
  end

  def get_opportunity_params(config_hash)
    config_hash['opportunity_view'] = params["opportunity_view"]["value"]
    if config_hash['opportunity_view'].to_bool
      config_hash['opportunity_fields'] = params[:opportunities].join(",") unless params[:opportunities].nil?
      config_hash['opportunity_labels'] = params['opportunity_labels']
      config_hash['agent_settings'] = params["agent_settings"]["value"]
      if config_hash['agent_settings'].to_bool
        config_hash["opportunity_stage_choices"] = service_obj.receive(:opportunity_stage_field)
      else
        @installed_app.configs[:inputs].delete("opportunity_stage_choices")
      end
    else
      opportunity_configs = [ "opportunity_fields", "opportunity_labels", "agent_settings", "opportunity_stage_choices" ]
      @installed_app.configs[:inputs] = @installed_app.configs[:inputs].except(*opportunity_configs)
    end
    config_hash
  end

  def fetch_metadata_fields
    salesforce_config = Hash.new
    contact_fields = service_obj.receive(:contact_fields)
    lead_fields = service_obj.receive(:lead_fields)
    account_fields = service_obj.receive(:account_fields)
    opportunity_fields = service_obj.receive(:opportunity_fields)
    salesforce_config['contact_fields'] = contact_fields["field_labels"]
    salesforce_config['contact_fields_types'] = contact_fields["field_data_types"]
    IntegrationServices::Services::SalesforceService::CONTACT_CUSTOM_FIELDS.each do |k|
      salesforce_config['contact_fields'].delete(k)  
    end
    salesforce_config['account_fields'] = account_fields["field_labels"]
    salesforce_config['account_fields_types'] = account_fields["field_data_types"]
    salesforce_config['lead_fields'] = lead_fields["field_labels"]
    salesforce_config['opportunity_fields'] = opportunity_fields
    salesforce_config
  end

  def service_obj
    @salesforce_obj ||= IntegrationServices::Services::SalesforceService.new(@installed_app, {},:user_agent => request.user_agent)
  end

  def load_app
    @application = Integrations::Application.find_by_name(APP_NAME)
  end

  def load_installed_app
    @installed_app = current_account.installed_applications.find_by_application_id(@application.id)
    unless @installed_app
      flash[:error] = t(:'flash.application.not_installed')
      redirect_to integrations_applications_path
    end
  end

  def salesforce_sync_option?
    @installed_app.configs_salesforce_sync_option.to_s.to_bool
  end

  def get_app_configs
    key_options = { :account_id => current_account.id, :provider => "salesforce"}
    kv_store = Redis::KeyValueStore.new(Redis::KeySpec.new(Redis::RedisKeys::APPS_AUTH_REDIRECT_OAUTH, key_options))
    kv_store.group = :integration
    app_config = JSON.parse(kv_store.get_key)
    raise "OAuth Token is nil" if app_config["oauth_token"].nil?
    app_config
  end

  def set_metadata_in_redis
    redis_key = "cloud_elements_salesforce:#{current_account.id}"
    $redis_others.setex(redis_key, 5.minutes, fetch_metadata_fields.to_json)
    $redis_others.expire(redis_key, 5.minutes)
  end
end