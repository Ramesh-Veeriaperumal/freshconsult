class Integrations::CloudElements::CrmController < Integrations::CloudElementsController
  include Integrations::CloudElements::Crm::Constant
  include Integrations::CloudElements::Constant
  skip_before_filter :check_privilege, :verify_authenticity_token, :only => :event_notification
  before_filter :check_feature, :verify_authenticity, :except => :event_notification
  before_filter :build_installed_app, :only => [:instances, :create]
  before_filter :load_installed_app, :only => [:edit, :update]
  before_filter :update_obj_transformation, :only => [:update]
  before_filter :update_formula_inst, :only => [:update]
  
  def settings
    build_setting_configs "settings"
    render :template => "integrations/applications/crm_settings"
  end

  def create
    el_response = create_element_instance( crm_payload, @metadata )
    redirect_to "#{request.protocol}#{request.host_with_port}#{integrations_cloud_elements_crm_instances_path}?state=#{params[:state]}&method=post&id=#{el_response['id']}&token=#{CGI::escape(el_response['token'])}"
  rescue => e
    hash = build_setting_configs "create"
    flash[:error] = t(:'flash.application.install.cloud_element_settings_failure')
    render :template => "integrations/applications/crm_settings", :locals => {:configs => hash}
  end

  def instances
    if params[:id].present? and params[:token].present?
      el_response, el_response_id, el_response_token = true, params[:id], params[:token]
    else
      el_response = create_element_instance( crm_payload, @metadata )
      el_response_id, el_response_token = el_response['id'], el_response['token']
    end
    fd_response = create_element_instance( fd_payload, @metadata )
    fetch_metadata_fields(el_response_token)
    formula_resp = create_formula_inst(el_response_id, fd_response['id'])
    app_configs = get_app_configs(el_response_token, el_response_id, fd_response['id'], formula_resp['id'])
    @installed_app.configs[:inputs].merge!(app_configs)
    @installed_app.save!
    flash[:notice] = t(:'flash.application.install.cloud_element_success')
    render_settings
  rescue => e
    delete_formula_instance_error request.user_agent, formula_resp['id'] if formula_resp.present? and formula_resp['id'].present?
    Integrations::CloudElementsDeleteWorker.perform_async({:element_id => el_response_id, :app_id => @installed_app.application_id}) if el_response.present? and el_response_id.present?
    Integrations::CloudElementsDeleteWorker.perform_async({:element_id => fd_response['id'], :app_id => @installed_app.application_id}) if fd_response.present? and fd_response['id'].present?
    NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in installing the application: #{e.message}", :account_id => current_account.id}})
    flash[:error] = t(:'flash.application.install.error')
    redirect_to integrations_applications_path 
  end

  def edit
    fetch_metadata_fields(@installed_app.configs_element_token)
    @element_config['enble_sync'] = @installed_app.configs_enble_sync
    default_mapped_fields
    construct_synced_contacts
    render_settings
  rescue => e
    NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in installing the application: #{e.message}", :account_id => current_account.id}})
    flash[:error] = t(:'flash.application.update.error')
    redirect_to integrations_applications_path
  end

  def update
    @installed_app.set_configs get_metadata_fields
    @installed_app.save!
    flash[:notice] = t(:'flash.application.update.success')
    redirect_to integrations_applications_path
  rescue => e
    NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in updating the application: #{e.message}", :account_id => current_account.id}})
    flash[:error] = t(:'flash.application.update.error')
    redirect_to integrations_applications_path
  end

  def event_notification
    render :json => {:status => '200 Ok'}
  end

  private
  
    def crm_payload
      json_payload = "Integrations::CloudElements::Crm::Constant::#{element.upcase}_JSON".constantize
      json_payload % instance_hash
    end

    def fd_payload
      json_payload = FRESHDESK_JSON
      api_key = current_user.single_access_token
      JSON.generate(json_payload) % {:api_key => api_key, :subdomain => subdomain, :fd_instance_name => "freshdesk_#{element}_#{subdomain}_#{current_account.id}" }
    end

    def instance_hash
      hash = {}
      if OAUTH_ELEMENTS.include? element
        hash[:refresh_token] = get_metadata_from_redis["refresh_token"]
        hash[:api_key] = Integrations::OAUTH_CONFIG_HASH[element]["consumer_token"]
        hash[:api_secret] = Integrations::OAUTH_CONFIG_HASH[element]["consumer_secret"]
      else
        constant_file = read_constant_file
        constant_file["keys"].each do |field|
          hash[field.to_sym] = params["#{field}_label"]
        end
      end
      hash[:callback_url] = "https://#{current_account.full_domain}" # mention ngrok for development environment.
      hash[:element_name] = "#{element}_#{subdomain}_#{current_account.id}"
      hash
    end

    def subdomain
      current_account.domain # mention ngrok for development environment.
    end

    def fetch_metadata_fields(element_token)
      crm_element_metadata_fields(element_token)
      fd_metadata_fields
    end

    def crm_element_metadata_fields(element_token)
      @element_config = Hash.new
      metadata = @metadata.merge({ :element_token => element_token })
      constant_file = read_constant_file
      constant_file['objects'].each do |key, obj|
        metadata[:object] = obj
        element_metadata = service_obj({},metadata).receive("#{key}_metadata".to_sym)
        hash = map_fields( element_metadata )
        @element_config["#{key}_fields"] = hash['fields_hash']
        @element_config["#{key}_fields_types"] = hash['data_type_hash']
      end
      delete_crm_custom_fields
    end

    def delete_crm_custom_fields
      file = read_constant_file
      file['delete_fields'].each do |k,v|
        @element_config[k].delete(v)
      end
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

    def map_fields(metadata)
      fields_hash = {}
      data_type_hash = {}
      metadata['fields'].each do |field|
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
      custom_fields = read_constant_file['fd_delete_fields']
      object.each do |field|
        unless custom_fields.include? field[:name]
          fields_hash[field[:name]] = field[:label]
          data_type_hash[field[:label]] = field.dom_type.to_s
        end
      end
      {'fields_hash' => fields_hash, 'data_type_hash' => data_type_hash }
    end

    def render_settings
      template = ( MAPPING_ELEMENTS.include? element.to_sym) ? "integrations/applications/crm_sync" : "integrations/applications/crm_fields"
      render :template => template
    end

    def get_app_configs( element_token, element_instance_id, fd_instance_id, formula_instance_id )
      element_config = default_mapped_fields
      config_hash = Hash.new
      config_hash = get_metadata_from_redis if OAUTH_ELEMENTS.include? element
      config_hash['element_token'] = element_token
      config_hash['element_instance_id'] = element_instance_id
      config_hash['fd_instance_id'] = fd_instance_id
      config_hash['crm_to_helpdesk_formula_instance'] = formula_instance_id
      config_hash['enble_sync'] = nil
      config_hash['companies'] = get_selected_field_arrays(element_config['existing_companies'])
      config_hash['contacts'] = get_selected_field_arrays(element_config['existing_contacts'])
      config_hash
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

    def update_obj_transformation
      sync_hash = get_synced_objects
      @contact_metadata = @metadata.merge({:object => 'fdContact', :method => params[:method]})
      @account_metadata = @metadata.merge({:object => 'fdCompany', :method => params[:method]})
      element_object_transformation sync_hash, @installed_app.configs_element_instance_id, "crm"
      element_object_transformation sync_hash, @installed_app.configs_fd_instance_id, "fd"
    rescue => e
      NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in updating the application: #{e.message}", :account_id => current_account.id}})
      flash[:error] = t(:'flash.application.update.error')
      redirect_to integrations_applications_path
    end

    def element_object_transformation sync_hash, instance_id , type
      constant_file = read_constant_file 
      contact_metadata = @contact_metadata.merge({:instance_id => instance_id, :update_action => @installed_app.configs_update_action}) 
      account_metadata = @account_metadata.merge({:instance_id => instance_id, :update_action => @installed_app.configs_update_action})
      instance_object_definition( obj_def_payload(sync_hash["contact_synced"], sync_hash["contact_fields"]), contact_metadata )
      instance_object_definition( obj_def_payload(sync_hash["account_synced"], sync_hash["account_fields"]), account_metadata )
      if type.eql? "crm"
        instance_transformation( crm_element_trans_payload(sync_hash["contact_synced"], constant_file['objects']['contact'], sync_hash["contact_fields"]), contact_metadata )
        instance_transformation( crm_element_trans_payload(sync_hash["account_synced"], constant_file['objects']['account'], sync_hash["account_fields"]), account_metadata )
      else
        instance_transformation( fd_trans_payload(sync_hash["contact_synced"],'','contacts', sync_hash["contact_fields"] ), contact_metadata )
        instance_transformation( fd_trans_payload(sync_hash["account_synced"],'customer','accounts', sync_hash["account_fields"]), account_metadata )
      end

    end

    def obj_def_payload obj_synced, obj_fields
      hash = {}
      arr = Array.new
      obj_synced.each do |obj|
        if obj_fields['seek_fields'].include? obj['fd_field']
          path = "FD_slave_#{obj['fd_field']}"
        else
          type = obj_fields['fields_hash'][obj['fd_field']].to_s
          path = "FD_slave_#{obj['fd_field']}_type_#{type}"
        end
        arr.push({
          'path' => path,
          'type' => 'string'      
        })
      end
      hash[:fields] = arr
      JSON.generate(hash)
    end

    def crm_element_trans_payload obj_synced, obj_name, obj_fields
      arr = Array.new
      obj_synced.each do |obj|
        if obj_fields['seek_fields'].include? obj['fd_field']
          path = "FD_slave_#{obj['fd_field']}"
        else
          type = obj_fields['fields_hash'][obj['fd_field']].to_s
          path = "FD_slave_#{obj['fd_field']}_type_#{type}"
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
            path = "FD_slave_#{obj['fd_field']}"
          else
            type = obj_fields['fields_hash'][obj['fd_field']].to_s
            path = "FD_slave_#{obj['fd_field']}_type_#{type}"
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
            path = "FD_slave_#{obj['fd_field']}"
          else
            type = obj_fields['fields_hash'][obj['fd_field']].to_s
            path = "FD_slave_#{obj['fd_field']}_type_#{type}"
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
      JSON.generate(json_payload) % {:object_name => obj_name}
    end

    def create_formula_inst( element_instance_id, fd_instance_id )
      formula_id = Integrations::CRM_TO_HELPDESK_FORMULA_ID[element]
      metadata = @metadata.merge({:formula_id => formula_id})
      payload = formula_instance_payload( "#{element}_#{subdomain}_#{current_account.id}", element_instance_id, fd_instance_id )
      create_formula_instance(payload, metadata) 
    end

    def update_formula_inst
      formula_id = Integrations::CRM_TO_HELPDESK_FORMULA_ID[element]
      metadata = @metadata.merge({:formula_id => formula_id, :formula_instance_id => @installed_app.configs_crm_to_helpdesk_formula_instance})
      payload = formula_instance_payload( "#{element}_#{subdomain}_#{current_account.id}", @installed_app.configs_element_instance_id, @installed_app.configs_fd_instance_id)
      update_formula_instance(payload, metadata)
    rescue => e
      NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in installing the application: #{e.message}", :account_id => current_account.id}})
      flash[:error] = t(:'flash.application.update.error')
      redirect_to integrations_applications_path and return 
    end

    def formula_instance_payload instance_name, source, target
      json_payload = FORMULA_INSTANCE_JSON
      active = params[:enble_sync] == "on"
      json_payload % {:formula_instance => instance_name, :source => source ,:target => target, :active => active}
    end

    def get_metadata_fields
      config_hash = Hash.new 
      config_hash['enble_sync'] = params[:enble_sync]
      config_hash['companies'] = get_selected_field_arrays(params[:inputs][:companies])
      config_hash['contacts'] = get_selected_field_arrays(params[:inputs][:contacts])
      config_hash['update_action'] = "true"
      config_hash
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

    def load_installed_app
      @installed_app = current_account.installed_applications.find_by_application_id(app.id)
      @metadata = {:user_agent => request.user_agent}
      unless @installed_app
        flash[:error] = t(:'flash.application.not_installed')
        redirect_to integrations_applications_path
      end
    end

    def construct_synced_contacts
      @element_config['existing_contacts'] = Array.new
      contact_synced = @installed_app.configs_contacts
      contact_synced['fd_fields'].each_with_index do |fd_field, index|
        @element_config['existing_contacts'].push({'fd_field' => fd_field, 'sf_field' => contact_synced['sf_fields'][index]})
      end

      @element_config['existing_companies'] = Array.new
      account_synced = @installed_app.configs_companies
      account_synced['fd_fields'].each_with_index do |fd_field, index|
        @element_config['existing_companies'].push({'fd_field' => fd_field, 'sf_field' => account_synced['sf_fields'][index]})
      end
    end

    def default_mapped_fields
      file = read_constant_file
      @element_config['existing_companies'] = file['existing_companies']
      @element_config['existing_contacts'] = file['existing_contacts']
      @element_config['element_validator'] = file['validator']
      @element_config['fd_validator'] = file['fd_validator']
      @element_config['objects']= file['objects'].keys #check the usage.
      @element_config
    end

    def delete_element_instance_error user_agent, element_instance_id
      app_name = @installed_app.application.name
      metadata = {:user_agent => user_agent, :element_instance_id => element_instance_id }
      service_obj({},metadata).receive(:delete_element_instance)
    end

    def delete_formula_instance_error user_agent, formula_instance_id
      app_name = @installed_app.application.name
      formula_id = Integrations::CRM_TO_HELPDESK_FORMULA_ID[app_name]
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

    def read_constant_file
      "Integrations::CloudElements::Crm::Constant::#{element.upcase}".constantize
    end

    def build_setting_configs method
      constant_file = read_constant_file
      @settings = Hash.new
      @settings["keys"] = constant_file["keys"]
      @settings["app_name"] = element
      if method.eql? "create"
        hash = {}
        constant_file["keys"].each do |field|
          hash[field] = params["#{field}_label"]
        end
        hash
      end
    end

    def check_feature
      unless current_account.features?(FEATURE[element])
        flash[:error] = t(:'flash.application.install.no_feature_error')
        redirect_to integrations_applications_path and return
      end 
    end
end