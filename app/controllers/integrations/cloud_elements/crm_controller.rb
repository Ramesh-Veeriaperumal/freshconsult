class Integrations::CloudElements::CrmController < Integrations::CloudElementsController

  before_filter :build_installed_app, :only => [:instances, :install]
  before_filter :get_app_configs, :create_obj_transformation, :formula_instance, :only => [:install]
  before_filter :load_installed_app, :only => [:edit, :update]
  before_filter :update_obj_transformation, :only => [:update]
  
  def instances
    el_response = create_element_instance( crm_payload, @metadata )
    fd_response = create_element_instance( fd_payload, @metadata )
    set_redis_keys({ :element_token => el_response['token'], :element_instance_id => el_response['id'], :fd_instance_id => fd_response['id']})
    fetch_metadata_fields(el_response['token'])
    default_mapped_fields
    @sync_type = Integrations::CloudElements::Crm::Constant::CRM_SYNC_TYPE
    @action = 'install'
    @installed_app = nil
    render_settings
  end

  def install
    @installed_app.configs[:inputs] = @app_config
    @installed_app.set_configs get_metadata_fields
    @installed_app.save!
    flash[:notice] = t(:'flash.application.install.success')
    redirect_to integrations_applications_path
  rescue => e
    NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in installing the application : #{e.message}"}})
    flash[:error] = t(:'flash.application.install.error')
    redirect_to integrations_applications_path
  end

  def edit
    @action = 'update'
    @sync_type = Integrations::CloudElements::Crm::Constant::CRM_SYNC_TYPE
    fetch_metadata_fields(@app_config['element_token'])
    @element_config['enble_sync'] = @app_config['enble_sync']
    @element_config['crm_sync_type'] = @app_config['crm_sync_type']
    default_mapped_fields
    construct_synced_contacts
    render_settings
  end

  def update
    @installed_app.set_configs get_metadata_fields
    @installed_app.save!
    flash[:notice] = t(:'flash.application.install.succes')
    redirect_to integrations_applications_path
  rescue => e
    NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in updating the application : #{e.message}"}})
    flash[:error] = t(:'flash.application.install.error')
    redirect_to integrations_applications_path
  end

  private

    def element
      Integrations::CloudElements::Crm::Constant::APP_NAMES[params[:state].to_sym]
    end
  
    def crm_payload
      json_payload = File.read("lib/integrations/cloud_elements/crm/#{element}/#{element}.json")
      json_payload % instance_hash
    end

    def fd_payload
      json_payload = File.read("lib/integrations/cloud_elements/freshdesk.json")
      json_payload % {:api_key => 'WMhJrGqFy1qNxMdDLT', :subdomain => 'sumitjagdambacom', :fd_instance_name => "freshdesk_#{current_account.id}" }
    end

    def instance_hash
      hash = {}
      constant_file = JSON.parse(File.read("lib/integrations/cloud_elements/crm/#{element}/constant.json"))
      constant_file['parameters'].each do |param|
         hash["#{param}".to_sym] = params["#{param}".to_sym]
      end
      hash[:element_name] = "#{element}_#{current_account.id}"
      hash
    end

    def set_redis_keys(config_params, expire_time = nil)
      key_options = { :account_id => current_account.id, :provider => app.name}
      key_spec = Redis::KeySpec.new(Redis::RedisKeys::APPS_AUTH_REDIRECT_OAUTH, key_options)
      Redis::KeyValueStore.new(key_spec, config_params.to_json, {:group => :integration, :expire => expire_time || 900}).set_key
    end

    def fetch_metadata_fields(element_token)
      crm_element_metadata_fields(element_token)
      fd_metadata_fields
    end

    def crm_element_metadata_fields(element_token)
      @element_config = Hash.new
      metadata = @metadata.merge({ :element_token => element_token })
      constant_file = JSON.parse(File.read("lib/integrations/cloud_elements/crm/#{element}/constant.json"))
      constant_file['objects'].each do |key, obj|
        metadata[:object] = obj
        element_metadata = service_obj({},metadata).receive("#{key}_metadata".to_sym)
        @element_config["#{key}_fields"] = map_fields( element_metadata )
      end
    end

    def fd_metadata_fields
      contact_metadata = current_account.contact_form.fields
      company_metadata = current_account.company_form.fields
      @element_config['fd_contact'] = fd_fields_hash( contact_metadata )
      @element_config['fd_company'] = fd_fields_hash( company_metadata )
    end

    def map_fields(metadata)
      hash = {}
      metadata['fields'].each do |field|
        hash[field['vendorPath']] = field['vendorDisplayName'] || field['vendorPath']
      end
      hash
    end

    def fd_fields_hash(object)
      hash = {}
      object.each do |field|
        hash[field[:name]] = field[:label]
      end
      hash
    end

    def render_settings
      render :template => "integrations/applications/salesforce_fields"
    rescue => e
      NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in installing the application : #{e.message}"}})
      flash[:error] = t(:'flash.application.install.error')
      redirect_to integrations_applications_path
    end

    def get_app_configs
      key_options = { :account_id => current_account.id, :provider => app.name}
      kv_store = Redis::KeyValueStore.new(Redis::KeySpec.new(Redis::RedisKeys::APPS_AUTH_REDIRECT_OAUTH, key_options))
      kv_store.group = :integration
      @app_config = JSON.parse(kv_store.get_key)
    end

    def get_synced_objects
      @contact_synced = params[:inputs][:contacts]
      @account_synced = params[:inputs][:companies]
    end

    def create_obj_transformation
      get_synced_objects
      @contact_metadata = @metadata.merge({:object => 'fdContact', :method => 'post'})
      @account_metadata = @metadata.merge({:object => 'fdCompany', :method => 'post'})
      crm_element_object_transformation
      freshdesk_object_transformation
    end

    def update_obj_transformation
      get_synced_objects
      @contact_metadata = @metadata.merge({:object => 'fdContact', :method => 'put'})
      @account_metadata = @metadata.merge({:object => 'fdCompany', :method => 'put'})
      crm_element_object_transformation
      freshdesk_object_transformation
    end

    def crm_element_object_transformation
      contact_metadata = @contact_metadata.merge({:instance_id => @app_config['element_instance_id']}) 
      account_metadata = @account_metadata.merge({:instance_id => @app_config['element_instance_id']})
      constant_file = JSON.parse(File.read("lib/integrations/cloud_elements/crm/#{element}/constant.json")) 
      instance_object_definition( obj_def_payload(@contact_synced), contact_metadata )
      instance_object_definition( obj_def_payload(@account_synced), account_metadata )
      instance_transformation( crm_element_trans_payload(@contact_synced, constant_file['objects']['contact']), contact_metadata )
      instance_transformation( crm_element_trans_payload(@account_synced, constant_file['objects']['account']), account_metadata )
    end

    def freshdesk_object_transformation
      contact_metadata = @contact_metadata.merge({:instance_id => @app_config['fd_instance_id']}) 
      account_metadata = @account_metadata.merge({:instance_id => @app_config['fd_instance_id']})
      instance_object_definition( obj_def_payload(@contact_synced), contact_metadata )
      instance_object_definition( obj_def_payload(@account_synced), account_metadata )
      instance_transformation( fd_trans_payload(@contact_synced,'user','contacts'), contact_metadata )
      instance_transformation( fd_trans_payload(@account_synced,'customer','accounts'), account_metadata )
    end

    def obj_def_payload obj_synced
      hash = {}
      arr = Array.new
      obj_synced.each do |obj|
        arr.push({
          'path' => "FD_#{obj['fd_field']}",
          'type' => 'string'      
        })
      end
      hash[:fields] = arr
      JSON.generate(hash)
    end

    def crm_element_trans_payload obj_synced, obj_name
      arr = Array.new
      obj_synced.each do |obj|
        arr.push({
          "path" => "FD_#{obj['fd_field']}",
          "vendorPath" => obj['sf_field']
        })
      end
      parse_trans_payload( arr, obj_name)
    end

    def fd_trans_payload obj_synced, fd_obj, obj_name
      arr = Array.new
      obj_synced.each do |obj|
        arr.push({
          "path" => "FD_#{obj['fd_field']}",
          "vendorPath" => "#{fd_obj}.#{obj['fd_field']}"
        })
      end
      parse_trans_payload( arr, obj_name)
    end

    def parse_trans_payload arr, obj_name
      json_payload = JSON.parse(File.read("lib/integrations/cloud_elements/instance_transformation.json"))
      json_payload['fields'] = arr
      JSON.generate(json_payload) % {:object_name => obj_name}
    end

    def formula_instance
      formula_id = Integrations::CloudElements::Crm::Constant::FORMULA_ID[params[:state].to_sym]
      metadata = @metadata.merge({:formula_id => formula_id})
      response = create_formula_instance(formula_instance_payload, metadata)
      @app_config['formula_instance_id'] = response['id']
    end

    def formula_instance_payload
      json_payload = File.read("lib/integrations/cloud_elements/formula_instance.json")
      json_payload % {:formula_instance => "Formula_#{params[:state]}_#{current_account.id}", :element_instance_id => @app_config['element_instance_id'],:fd_instance_id => @app_config['fd_instance_id']}
    end

    def get_metadata_fields
      config_hash = Hash.new 
      config_hash['enble_sync'] = params[:enble_sync]
      config_hash['crm_sync_type'] = params[:crm_sync_type]
      config_hash['contact_fields'] = params[:contacts].join(",") unless params[:contacts].nil?
      config_hash['lead_fields'] = params[:leads].join(",") unless params[:leads].nil?
      config_hash['account_fields'] = params[:accounts].join(",") unless params[:accounts].nil?
      config_hash['contact_labels'] = params['contact_labels']
      config_hash['lead_labels'] = params['lead_labels']
      config_hash['account_labels'] = params['account_labels']
      config_hash['companies'] = get_selected_field_arrays(params[:inputs][:companies])
      config_hash['contacts'] = get_selected_field_arrays(params[:inputs][:contacts])
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
      @app_config = @installed_app.configs[:inputs]
      @metadata = {:user_agent => request.user_agent}
      unless @installed_app
        flash[:error] = t(:'flash.application.not_installed')
        redirect_to integrations_applications_path
      end
    end

    def construct_synced_contacts
      arr = Array.new
      contact_synced = @installed_app.configs_contacts
      account_synced = @installed_app.configs_companies
      contact_synced['fd_fields'].each_with_index do |fd_field, index|
        arr.push({'fd_field' => fd_field, 'sf_field' => contact_synced['sf_fields'][index]})
      end
      @installed_app.configs_contacts = arr
      arr = []
      account_synced['fd_fields'].each_with_index do |fd_field, index|
        arr.push({'fd_field' => fd_field, 'sf_field' => account_synced['sf_fields'][index]})
      end
      @installed_app.configs_companies = arr
    end

    def default_mapped_fields
      file = JSON.parse(File.read("lib/integrations/cloud_elements/crm/#{element}/constant.json"))
      @element_config['existing_companies'] = file['existing_companies']
      @element_config['existing_contacts'] = file['existing_contacts']
      @element_config['default_fields'] = file['default_fields']
    end

end