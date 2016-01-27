class Integrations::SalesforceController < Admin::AdminController

  before_filter :load_app
  before_filter :load_installed_app, :only => [:edit, :update]
  APP_NAME = Integrations::Constants::APP_NAMES[:salesforce]
  CONTACT_TYPES = {1=>"text", 2=>"text", 3=>"email", 4=>"phone_number", 5=>"phone_number", 6=>"text",
   7=>"text", 8=>"checkbox", 9=>"paragraph", 10=>"dropdown", 11=>"dropdown", 12=>"text", 13=>"paragraph"} 
   # 1001=>"text", 1002=> "paragraph", 1003 => "checkbox", 1004=> "number", 1005=> "dropdown", 
   # 1006=>"phone_number", 1007=>"url", 1008=>"date"} 

  def new
    @installed_app = current_account.installed_applications.build(:application => @application)
    @installed_app.configs = { :inputs => {} }
    @installed_app.configs[:inputs] = get_app_configs
    @salesforce_config = fetch_metadata_fields
    @salesforce_config['enable_sync'] = "on"
    @salesforce_config['features']= current_account.features?(:cloud_elements_crm_sync)
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
    if current_account.features?(:salesforce_sync)
      config_hash['salesforce_sync_option'] = params["salesforce_sync_option"]["value"]
    end
    config_hash
  end

  def fetch_metadata_fields
    salesforce_config = Hash.new
    salesforce_config['contact_fields'] = service_obj.receive(:contact_fields)
    salesforce_config['contact_fields_types']= get_contact_field_types(salesforce_config['contact_fields'], 
      Integrations::Constants::SF_METADATA_CONTACTS)

    IntegrationServices::Services::SalesforceService::CONTACT_CUSTOM_FIELDS.each do |k|
      salesforce_config['contact_fields'].delete(k)  
    end
    salesforce_config['lead_fields'] = service_obj.receive(:lead_fields)
    salesforce_config['account_fields'] = service_obj.receive(:account_fields)
    #added content for field mapping
    salesforce_config['fd_company'] = get_freshdesk_fields_hash(current_account.company_form.fields)
    salesforce_config['fd_contact'], salesforce_config['fd_contact_types'] = get_freshdesk_contact_fields_hash(current_account.contact_form.all_fields)
    salesforce_config
  end

  def get_freshdesk_fields_hash(fields)
    field_labels = Array.new
    field_labels = fields.map{|f| [f["label"], f[:name]]}
  end

  def get_freshdesk_contact_fields_hash(fields)
    field_labels = Hash.new
    field_types = Hash.new
    fields.each do |f|
      field_labels[f["label"]]= f[:name]
      field_types[f["label"]]= CONTACT_TYPES[f["field_type"]]
    end
    [field_labels, field_types]
  end

  def get_contact_field_types(contact_fields, field_types)
    fields = field_types["fields"]
    data_types = Hash.new 
    field_data_types = Hash.new
    fields.each do|f|
      data_types[f["vendorPath"]] = f["type"]
    end
    contact_fields.each do |key, value|
      field_data_types[value] = data_types[key]
    end
    #key should be label
    field_data_types
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
end