class Integrations::SalesforceController < Admin::AdminController

  before_filter :load_app
  before_filter :load_installed_app, :only => [:edit, :update]
  APP_NAME = Integrations::Constants::APP_NAMES[:salesforce]


  def new
    @sync_type = Integrations::Constants::SALESFORCE_SYNC_TYPE
    @installed_app = current_account.installed_applications.build(:application => @application)
    @installed_app.configs = { :inputs => {} }
    @installed_app.configs[:inputs] = get_app_configs
    @salesforce_config = fetch_metadata_fields
    @salesforce_config['enble_sync'] = @installed_app.configs[:inputs]['enble_sync']
    @salesforce_config['contacts_sync_type'] = @installed_app.configs[:inputs]['contacts_sync_type']
    @salesforce_config['crm_sync_type'] = @installed_app.configs[:inputs]['crm_sync_type']
    @salesforce_config['sf_contact'] = convert_map_to_hash(@salesforce_config['contact_fields'])
    @salesforce_config['sf_company'] = convert_map_to_hash(@salesforce_config['account_fields'])
    @salesforce_config['fd_company'] = convert_object_to_hash(current_account.company_form.fields)
    @salesforce_config['fd_contact'] = convert_object_to_hash(current_account.contact_form.fields)
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
    config_hash['enble_sync'] = params[:enble_sync]
    config_hash['contacts_sync_type'] = params[:contacts_sync_type]
    config_hash['crm_sync_type'] = params[:crm_sync_type]
    config_hash['contact_fields'] = params[:contacts].join(",") unless params[:contacts].nil?
    config_hash['lead_fields'] = params[:leads].join(",") unless params[:leads].nil?
    config_hash['account_fields'] = params[:accounts].join(",") unless params[:accounts].nil?
    config_hash['contact_labels'] = params['contact_labels']
    config_hash['lead_labels'] = params['lead_labels']
    config_hash['account_labels'] = params['account_labels']
    config_hash['companies'] = get_selected_field_arrays(params[:inputs][:companies])
    config_hash['contacts'] = get_selected_field_arrays(params[:inputs][:contacts])
    if current_account.features?(:salesforce_sync)
      config_hash['salesforce_sync_option'] = params["salesforce_sync_option"]["value"]
    end
    config_hash
  end

  def fetch_metadata_fields
    salesforce_config = Hash.new
    salesforce_config['contact_fields'] = service_obj.receive(:contact_fields)
    IntegrationServices::Services::SalesforceService::CONTACT_CUSTOM_FIELDS.each do |k|
      salesforce_config['contact_fields'].delete(k)  
    end  
    salesforce_config['lead_fields'] = service_obj.receive(:lead_fields)
    salesforce_config['account_fields'] = service_obj.receive(:account_fields)
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

   def convert_map_to_hash(map)
    arr = Array.new
    map.each{|key, val|
      has = Hash.new
      if key == "Address"
        next
      end
      has["id"] = key
      has["name"] = val
      arr.push(has)
    }
    arr
   end
 
   def convert_object_to_hash(object)
    arr = Array.new
    object.each{|field|
      has = Hash.new
      has["id"] = field[:name]
      has["name"] = field["label"]
      arr.push(has)
    }
    arr
   end

  def get_selected_field_arrays(fields)
    sf_fields = []
    fd_fields = []
    fields.each { |field|
      sf_fields << field["sf_field"]
      fd_fields << field["fd_field"]
    }
    {"fd_fields" => fd_fields, "sf_fields" => sf_fields}
  end

end