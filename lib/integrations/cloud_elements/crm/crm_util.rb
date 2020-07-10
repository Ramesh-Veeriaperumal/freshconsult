module Integrations::CloudElements::Crm::CrmUtil
  include Integrations::CloudElements::Crm::Constant
  include Integrations::CloudElements::Constant

  def salesforce_v2_metadata_fields
    config_hash = set_config_hash
    config_hash['ticket_sync_option'] = params["ticket_sync_option"]["value"]
    handle_salesforce_ticket_sync if ticket_sync_option? || @installed_app.configs_ticket_sync_option.to_s.to_bool
    config_hash
  rescue => e
    Rails.logger.debug "Problem in salesforce_v2_metadata_fields Error - #{e.message}"
    NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in salesforce_v2_metadata_fields: #{e.message}", :account_id => current_account.id}})
    config_hash
  end

  def dynamics_v2_metadata_fields
    config_hash = set_config_hash
  rescue => e
    Rails.logger.debug "Problem in Dynamics_v2_metadata_fields Error - #{e.message}"
    NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in dynamics_v2_metadata_fields: #{e.message}", :account_id => current_account.id}})
  end

  def set_config_hash
    config_hash = Hash.new
    config_hash['lead_fields'] = params[:leads].join(",")
    config_hash['lead_labels'] = params['lead_labels']
    if params[:element_configs]["objects"].include? "contract"
      config_hash['contract_view'] = params[:contract_view][:value]
      if config_hash['contract_view'].to_bool
        config_hash['contract_fields'] = params[:contracts].join(",")
        config_hash['contract_labels'] = params['contract_labels']
      else
        contract_configs = [ "contract_fields", "contract_labels"]
        @installed_app.configs[:inputs] = @installed_app.configs[:inputs].except(*contract_configs)
      end
    end
    if params[:element_configs]["objects"].include? "order"    
      config_hash['order_view'] = params[:order_view][:value]
      if config_hash['order_view'].to_bool
        config_hash['order_fields'] = params[:orders].join(",")
        config_hash['order_labels'] = params['order_labels']
      else
        order_configs = [ "order_fields", "order_labels"]
        @installed_app.configs[:inputs] = @installed_app.configs[:inputs].except(*order_configs)
      end
    end
    config_hash = get_opportunity_params config_hash
  end

  def handle_salesforce_ticket_sync
    va_rules = @installed_app.va_rules
    if ticket_sync_option? && va_rules.blank?
      #disable the salesforce v1 va_rules if they are installing salesforce v2. If old installed app is present and va_rules is also present
      old_app_id = Integrations::Application.find_by_name("salesforce")
      old_installed_app = Integrations::InstalledApplication.find_by_application_id(old_app_id)
      if old_installed_app.present? && old_installed_app.va_rules.present?
        old_installed_app.va_rules.each do |v_r|
          v_r.update_attribute(:active,false) 
        end
        old_installed_app.configs_salesforce_sync_option = "0"
        old_installed_app.save!
      end
      ticket_obj = IntegrationServices::Services::SalesforceV2Service.new @installed_app, {}, @metadata
      ticket_obj.receive(:ticket_sync_install)
    elsif va_rules.present?
      va_rules.each do |v_r|
        v_r.update_attribute(:active,ticket_sync_option?) 
      end
    end
  end

  def formula_instance_payload instance_name, source, target, active
    json_payload = FORMULA_INSTANCE_JSON # During creation Both the formula instances will be active.
    json_payload % {:formula_instance => instance_name, :source => source ,:target => target, :active => active}
  end

  def migrate_integrated_resources
    # A sidekiq worker will be run only if the app is salesforce_v2 and for the first update action.
    unless @installed_app.configs_update_action
      Integrations::SalesforceIntegratedResourceMigrateWorker.perform_async     
    end
  end

  def instance_hash
    hash = {}
    if OAUTH_ELEMENTS.include? element
      hash[:refresh_token] = get_metadata_from_redis["refresh_token"]
      hash[:api_key] = Integrations::OAUTH_CONFIG_HASH[element]["consumer_token"]
      hash[:api_secret] = Integrations::OAUTH_CONFIG_HASH[element]["consumer_secret"]
    else
      constant_file = get_crm_constants
      constant_file["keys"].each do |field|
        hash[field.to_sym] = params["#{field}_label"]
      end
    end
    hash[:callback_url] = "https://#{current_account.full_domain}" # mention ngrok for development environment. "https://freshcloud.ngrok.io"
    hash[:element_name] = "#{element}_#{subdomain}_#{current_account.id}"
    hash
  end

  def crm_element_metadata_fields(element_token)
    @element_config = Hash.new
    @element_config['objects'] = []
    metadata = @metadata.merge({ :element_token => element_token })
    constant_file = get_crm_constants
    constant_file['objects'].each do |key, obj|
      metadata = @metadata.merge({ :element_token => element_token, :object => obj})
      element_metadata = service_obj({:object => key}, metadata).receive(:object_metadata)
      if element_metadata != 404
        hash = (key != "opportunity") ? map_fields(element_metadata) : map_opportunity_fields(element_metadata, constant_file['opportunity_keys'])
        @element_config["#{key}_fields"] = hash['fields_hash']
        @element_config["#{key}_fields_types"] = hash['data_type_hash']
        @element_config['objects'].push(key)
      end
    end
    @element_config['additional_fields'] = constant_file['additional_fields']
    @element_config['element_name'] = constant_file['element_name']
    delete_crm_custom_fields
  end

  def map_opportunity_fields metadata, opportunity_keys
    fields_hash = {}
    data_type_hash = {}
    metadata['fields'].each do |field|
      label = field['vendorDisplayName'] || field['vendorPath']
      fields_hash[field['vendorPath']] = label
      data_type_hash[label] = field['vendorNativeType']
      if(field['vendorPath'] == opportunity_keys['stage'])
        choices = field[opportunity_keys['choices']]
        @element_config["opportunity_stage_choices"] = choices.collect{|choice| choice[opportunity_keys["value"]]} # for dynamics this should be Names and
        @element_config["opportunity_stage_choices_ids"] = choices.collect{|choice| choice[opportunity_keys["id"]]} # This should be the code.
      end
    end
    {'fields_hash' => fields_hash, 'data_type_hash' => data_type_hash }
  end

  def fd_metadata_fields
    contact_metadata = current_account.contact_form.fields
    company_metadata = current_account.company_form.fields
    contact_hash = fd_fields_hash( contact_metadata)
    account_hash = fd_fields_hash( company_metadata)
    @element_config['element'] = element
    @element_config['fd_contact'] = contact_hash['fields_hash']
    @element_config['fd_contact_types'] = contact_hash['data_type_hash']
    @element_config['fd_company'] = account_hash['fields_hash']
    @element_config['fd_company_types'] = account_hash['data_type_hash']
  end

  def render_settings
    # template = ( MAPPING_ELEMENTS.include? element.to_sym) ? "integrations/applications/crm_sync" : "integrations/applications/crm_fields"
    template = "integrations/applications/crm_fields"
    render :template => template
  end

  def get_app_configs( element_token, element_instance_id, fd_instance_id, crm_formula_instance_id, fd_formula_instance_id )
    # Used to built the default app_configs before showing the settings page.
    element_config = default_mapped_fields
    config_hash = Hash.new
    config_hash = get_metadata_from_redis if OAUTH_ELEMENTS.include? element
    config_hash['element_token'] = element_token
    config_hash['element_instance_id'] = element_instance_id
    config_hash['fd_instance_id'] = fd_instance_id
    config_hash['crm_to_helpdesk_formula_instance'] = crm_formula_instance_id
    config_hash['helpdesk_to_crm_formula_instance'] = fd_formula_instance_id
    config_hash['enable_sync'] = nil
    config_hash['crm_sync_type'] = "FD_AND_CRM"
    config_hash['companies'] = get_selected_field_arrays(element_config['existing_companies'])
    config_hash['contacts'] = get_selected_field_arrays(element_config['existing_contacts'])
    @element_config['objects'].each do |object|
      config_hash["#{object}_fields"] = element_config['default_fields'][object].join(",")
      config_hash["#{object}_labels"] = element_config['default_labels'][object].join(",")
    end
    config_hash
  end

  def get_metadata_fields
    config_hash = Hash.new
    config_hash['enable_sync'] = params[:enable_sync]
    config_hash['companies'] = get_selected_field_arrays(params[:inputs][:companies])
    config_hash['contacts'] = get_selected_field_arrays(params[:inputs][:contacts])
    config_hash['update_action'] = "true" #This is a flag to know whether user has ever triggered the update_action or not.
    config_hash['contact_fields'] = params[:contacts].join(",") unless params[:contacts].nil?
    config_hash['contact_labels'] = params['contact_labels'] unless params[:contacts].nil?
    config_hash['account_fields'] = params[:accounts].join(",") unless params[:accounts].nil?
    config_hash['account_labels'] = params['account_labels'] unless params[:accounts].nil?
    config_hash['crm_sync_type'] = params['crm_sync_type']
    config_hash['master_type'] = params['master_type']
    config_hash['sync_frequency'] = params['sync_frequency']
    config_hash['app_name'] = element if @installed_app.configs_app_name.nil?
    config_hash.merge!(safe_send("#{element}_metadata_fields")) # To Built element specific Values.
    config_hash
  end

  def element_object_transformation sync_hash, instance_id , type, sync_frequency_change
    constant_file = get_crm_constants 
    contact_metadata = @contact_metadata.merge({:instance_id => instance_id, :update_action => @installed_app.configs_update_action}) 
    account_metadata = @account_metadata.merge({:instance_id => instance_id, :update_action => @installed_app.configs_update_action})
    instance_object_definition( obj_def_payload(sync_hash["contact_synced"], sync_hash["contact_fields"], source_of_truth), contact_metadata )
    instance_object_definition( obj_def_payload(sync_hash["account_synced"], sync_hash["account_fields"], source_of_truth), account_metadata )
    if type.eql? "crm"
      instance_transformation( crm_element_trans_payload(sync_hash["contact_synced"], constant_file['objects']['contact'], sync_hash["contact_fields"]), contact_metadata )
      instance_transformation( crm_element_trans_payload(sync_hash["account_synced"], constant_file['objects']['account'], sync_hash["account_fields"]), account_metadata )
    else
      instance_transformation( fd_trans_payload(sync_hash["contact_synced"],'','contacts', sync_hash["contact_fields"] ), contact_metadata )
      instance_transformation( fd_trans_payload(sync_hash["account_synced"],'customer','accounts', sync_hash["account_fields"]), account_metadata )
    end
    sync_type_changed, element_active = sync_type_changed? type
    if sync_frequency_change || sync_type_changed 
      element_configs = get_element_configs(instance_id)
      if sync_frequency_change && element_configs.present?
        poller_refresh_config = element_configs.select{|config| config["key"] == "event.poller.refresh_interval"}.first
        poller_refresh_config['propertyValue'] = SYNC_FREQUENCY[params['sync_frequency']]
        update_element_configs( instance_id, poller_refresh_config) # Inside cloud_elements controller
      end

      if sync_type_changed && element_configs.present?
        poller_notification_config = element_configs.select{|config| config["key"] == "event.notification.enabled"}.first
        poller_notification_config['propertyValue'] = element_active
        update_element_configs( instance_id, poller_notification_config)
      end
    end
  end

  def default_mapped_fields
    file = get_crm_constants
    # installed app is handled inside the crm_fields.html.erb
    @element_config['existing_companies'] = file['existing_companies']
    @element_config['existing_contacts'] = file['existing_contacts']
    @element_config['default_fields'] = file['default_visibility_fields']
    @element_config['default_labels'] = file['default_visibility_labels']
    @element_config['element_validator'] = file['validator']
    @element_config['fd_validator'] = file['fd_validator']
    # @element_config['objects']= file['objects'].keys
    @element_config['crm_sync_type'] = (@installed_app.configs_crm_sync_type.present?) ? @installed_app.configs_crm_sync_type : "FD_AND_CRM"
    @element_config['master_type'] = (@installed_app.configs_master_type.present?) ? @installed_app.configs_master_type : "CRM"
    @element_config['sync_frequency'] = (@installed_app.configs_sync_frequency.present?) ? @installed_app.configs_sync_frequency : "hourly"
    @element_config
  end

  def construct_synced_contacts
    @element_config['existing_contacts'] = Array.new
    contact_synced = @installed_app.configs_contacts
    contact_synced['fd_fields'].each_with_index do |fd_field, index|
      if @element_config["fd_contact"].keys.include? fd_field and @element_config["contact_fields"].keys.include? contact_synced['sf_fields'][index]
        @element_config['existing_contacts'].push({'fd_field' => fd_field, 'sf_field' => contact_synced['sf_fields'][index]})
      end
    end

    @element_config['existing_companies'] = Array.new
    account_synced = @installed_app.configs_companies
    account_synced['fd_fields'].each_with_index do |fd_field, index|
      if @element_config["fd_company"].keys.include? fd_field and @element_config["account_fields"].keys.include? account_synced['sf_fields'][index]
        @element_config['existing_companies'].push({'fd_field' => fd_field, 'sf_field' => account_synced['sf_fields'][index]})
      end
    end
  end

  def get_contact_account_name response, metadata
    fields = @installed_app.configs_contact_fields.split(",")
    if (fields.include? "AccountName") 
      constant = get_crm_constants
      account_ids = response["records"].map{|resp| resp["accountId"]}.compact
      if account_ids.present?
        query = account_ids.collect{|id| "#{constant['account_name_format']}='#{id}'"}.join(" OR ")
        payload = {:query => query}
        account_response = service_obj( payload, metadata).receive("get_contact_account_name")
        return response if account_response.nil?
        account_names_hash = get_account_names_hash account_response
        response["records"].each do |records|
          records["AccountName"] = account_names_hash[records["accountId"]] if records["accountId"].present?
        end
      end
    end
    response
  end

  def get_contact_accounts payload
    metadata = {:app_name => element, :element_token => @installed_app.configs_element_token, :object => get_crm_constants["objects"]["account"]}
    service_obj( payload, metadata).receive("fetch_user_selected_fields")
  end

  def get_contact_account_ids email ,metadata
    payload = {:email => email}
    metadata = {:app_name => element, :element_token => @installed_app.configs_element_token, :object => get_crm_constants["objects"]["contact"]}
    service_obj( payload, metadata).receive("get_contact_account_id")
  end

  private

  def subdomain
    current_account.domain # mention ngrok for development environment."freshcloud"
  end

  def get_account_names_hash account_response
    case element
    when "salesforce_v2"
      Hash[account_response.collect{|account| [account["Id"], account["Name"]]}]
    when "dynamics_v2"
      Hash[account_response.collect{|account| [account["attributes"]["accountid"], account["attributes"]["name"]]}]
    end
  end

  def delete_crm_custom_fields
    file = get_crm_constants
    file['delete_fields'].each do |key,value|
      #read an array and delete all the keys that matches the array.
      value.each{|v| @element_config[key].delete(v) if @element_config[key][v].present?} 
    end
  end

  def map_fields(metadata)
    fields_hash = {}
    data_type_hash = {}
    metadata['fields'].each do |field|
      #logic specific for dynamics opportunities
      label = field['vendorDisplayName'] || field['vendorPath']
      fields_hash[field['vendorPath']] = label
      data_type_hash[label] = field['vendorNativeType']
    end
    {'fields_hash' => fields_hash, 'data_type_hash' => data_type_hash }
  end

  def fd_fields_hash(object)
    fields_hash = {}
    data_type_hash = {}
    #To remove those custom fields that we will be syncing from the customers view
    custom_fields = get_crm_constants['fd_hide_fields']
    object.each do |field|
      unless custom_fields.include? field[:name]
        fields_hash[field[:name]] = field[:label]
        data_type_hash[field[:label]] = field.dom_type.to_s
      end
    end
    {'fields_hash' => fields_hash, 'data_type_hash' => data_type_hash }
  end

  def get_synced_objects
    contact_synced = params[:inputs][:contacts]
    contact_fields, account_fields = Hash.new, Hash.new
    contact_fields['fields_hash'] = current_account.contact_form.fields.map{|field| [field[:name], field.dom_type]}.to_h
    contact_fields['seek_fields'] = ["name", "email", "mobile", "phone"]
    account_synced = params[:inputs][:companies]
    account_fields['fields_hash'] = current_account.company_form.fields.map{|field| [field[:name], field.dom_type]}.to_h
    account_fields['seek_fields'] = ["name"]
    {"contact_synced" => contact_synced, "account_synced" => account_synced, "contact_fields" => contact_fields, "account_fields" => account_fields}
  end

  def source_of_truth
    (params["master_type"] == "CRM") ? "FD_slave" : "FD_master"
  end

  def obj_def_payload obj_synced, obj_fields, source_of_truth
    hash = {}
    arr = Array.new
    obj_synced.each do |obj|
      if obj_fields['seek_fields'].include? obj['fd_field']
        path = "#{source_of_truth}_#{obj['fd_field']}"
      else
        type = obj_fields['fields_hash'][obj['fd_field']].to_s
        path = "#{source_of_truth}_#{obj['fd_field']}_type_#{type}"
      end
      arr.push({
        'path' => path,
        'type' => 'string'      
      })
    end
    hash[:fields] = arr
    hash.to_json
  end

  def crm_element_trans_payload obj_synced, obj_name, obj_fields
    arr = Array.new
    obj_synced.each do |obj|
      if obj_fields['seek_fields'].include? obj['fd_field']
        path = "#{source_of_truth}_#{obj['fd_field']}"
      else
        type = obj_fields['fields_hash'][obj['fd_field']].to_s
        path = "#{source_of_truth}_#{obj['fd_field']}_type_#{type}"
      end
      arr.push({
        "path" => path,
        "vendorPath" => obj['sf_field']
      })
    end
    parse_trans_payload( arr, obj_name)
  end

  def fd_trans_payload obj_synced, fd_obj, obj_name, obj_fields
    arr = Array.new
    if fd_obj.present?
      obj_synced.each do |obj|
        vendor_path = (obj['fd_field'].index('cf_') == 0) ? "#{fd_obj}.custom_field.#{obj['fd_field']}" : "#{fd_obj}.#{obj['fd_field']}"
        if obj_fields['seek_fields'].include? obj['fd_field']
          path = "#{source_of_truth}_#{obj['fd_field']}"
        else
          type = obj_fields['fields_hash'][obj['fd_field']].to_s
          path = "#{source_of_truth}_#{obj['fd_field']}_type_#{type}"
        end
        arr.push({
          "path" => path,
          "vendorPath" => vendor_path
        })
      end
    else
      obj_synced.each do |obj|
        vendor_path = (obj['fd_field'].index('cf_') == 0) ? "custom_fields.#{obj['fd_field'][3..-1]}" : "#{obj['fd_field']}"
        if obj_fields['seek_fields'].include? obj['fd_field']
          path = "#{source_of_truth}_#{obj['fd_field']}"
        else
          type = obj_fields['fields_hash'][obj['fd_field']].to_s
          path = "#{source_of_truth}_#{obj['fd_field']}_type_#{type}"
        end
        arr.push({
          "path" => path,
          "vendorPath" => vendor_path
        })
      end
    end
    parse_trans_payload( arr, obj_name)
  end

  def parse_trans_payload arr, obj_name
    json_payload = INSTANCE_TRANSFORMATION_JSON
    json_payload['fields'] = arr
    json_payload.to_json % { object_name: obj_name }
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

  def delete_element_instance_error user_agent, element_instance_id
    app_name = @installed_app.application.name
    metadata = {:user_agent => user_agent, :element_instance_id => element_instance_id }
    service_obj({},metadata).receive(:delete_element_instance)
  end

  def delete_formula_instance_error user_agent, formula_instance_id, action
    app_name = @installed_app.application.name
    formula_id = (action == "crm") ? Integrations::CRM_TO_HELPDESK_FORMULA_ID[app_name] : Integrations::HELPDESK_TO_CRM_FORMULA_ID[app_name]
    metadata = {:user_agent => user_agent, :formula_id => formula_id, :formula_instance_id => formula_instance_id}
    service_obj({},metadata).receive(:delete_formula_instance)
  end

  def get_metadata_from_redis
    key_options = { :account_id => current_account.id, :provider => element }
    kv_store = Redis::KeyValueStore.new(Redis::KeySpec.new(Redis::RedisKeys::APPS_AUTH_REDIRECT_OAUTH, key_options))
    kv_store.group = :integration
    app_config = JSON.parse(kv_store.get_key)
    raise OAUTH_ERROR if app_config["oauth_token"].nil?
    app_config
  end

  def get_crm_constants
    "Integrations::CloudElements::Crm::Constant::#{element.upcase}".constantize
  end

  def build_setting_configs
    constant_file = get_crm_constants
    @settings = Hash.new
    @settings["keys"] = constant_file["keys"]
    @settings["app_name"] = element
  end

  def get_opportunity_params(config_hash)
    config_hash['opportunity_view'] = params[:opportunity_view][:value]
    if config_hash['opportunity_view'].to_bool
      config_hash['opportunity_fields'] = params[:opportunities].join(",") unless params[:opportunities].nil?
      config_hash['opportunity_labels'] = params[:opportunity_labels]
      config_hash['agent_settings'] = params[:agent_settings][:value]
      config_hash["opportunity_stage_choices"] = params[:opportunity_stage_choices_ids].split(",").zip(params[:opportunity_stage_choices].split(","))
    else
      opportunity_configs = [ "opportunity_fields", "opportunity_labels", "agent_settings", "opportunity_stage_choices" ]
      @installed_app.configs[:inputs] = @installed_app.configs[:inputs].except(*opportunity_configs)
    end
    config_hash
  rescue => e
    NewRelic.Agent.notice_error(e,{:custom_params => {:description => "Problem in Fetching the opportunity params: #{e.message}", :account_id => current_account.id}})
    config_hash
  end

  def check_sync_active type 
    #used to check the current statues of the Formula Instance for Updation.(Will happen everytime User updates)
    return false unless params[:enable_sync] == "on" #If sync is off both the Formula instances will be switched Off.
    return true if params['crm_sync_type'] == "FD_AND_CRM" #If Two-way sync is On both the instances will be switched On.
    (type == "crm") ? (params['crm_sync_type'] == "CRM_to_FD") : (params['crm_sync_type'] == "FD_to_CRM")
  end

  def sync_type_changed? type 
    # Used to check whether to update the element Instance or Not.(Will Update only if there is a change. since, this is a costly operation.)
    existing_type, new_type, change_active = @installed_app.configs_crm_sync_type, params['crm_sync_type'], [false, false]
    enable_sync_changed = params[:enable_sync] != @installed_app.configs_enable_sync
    if enable_sync_changed
      return [true, false] if params[:enable_sync] != "on"
      change_active = (type == "crm") ? (params['crm_sync_type'] == "FD_to_CRM" ? [true, false] : [true, true] )  : (params['crm_sync_type'] == "CRM_to_FD" ? [true, false] : [true, true])
    else
      return change_active if new_type == existing_type || params[:enable_sync] != "on"
      if type == "crm"
        # If the existing is "FD_AND_CRM" and new is "FD_to_CRM" sync should be off, :enable_sync should be "on".
        # If the existing is "CRM_to_FD" and new is "FD_to_CRM" sync should be off, :enable_sync should be "on".
        # If the existing is "FD_to_CRM" and new is "CRM_to_FD" sync should be on, :enable_sync should be "on".
        # If the existing is "FD_to_CRM" and new is "FD_AND_CRM" sync should be on, :enable_sync should be "on".
        # If the existing is "FD_AND_CRM" and new is "CRM_to_FD" No need to change.
        # If the existing is "CRM_to_FD" and new is "FD_AND_CRM" No need to change.
        change_active = [true, false] if new_type =="FD_to_CRM"
        change_active = [true, true] if existing_type == "FD_to_CRM"
      else
        change_active = [true, false] if new_type =="CRM_to_FD"
        change_active = [true, true] if existing_type == "CRM_to_FD"
      end
    end
    change_active
  end

  def ticket_sync_option?
    params["ticket_sync_option"]["value"].to_bool
  end

  def element_is_salesforce?
    element.eql? "salesforce_v2"
  end

end
