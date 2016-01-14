class Integrations::CloudElements::CrmController < Integrations::CloudElementsController
  include Integrations::CloudElements::Constant

  before_filter :build_installed_app, :only => [:instances]
  before_filter :get_app_configs, :get_synced_objects, :create_obj_def, :only => [:install]
  before_filter :get_synced_objects, :update_obj_def, :only => [:edit]
  
  def instances
    el_response = element_instance(crm_payload, user_agent)
    fd_response = element_instance(fd_payload, user_agent)
    set_redis_keys({ :element => params[:state], :element_token => el_response['token'], :element_instance_id => el_response['id'], :fd_instance_id => fd_response['id']})
    fetch_metadata_fields(el_response['token'])
    @action = 'install'
    @sync_type = CRM_SYNC_TYPE
    render_settings
  end

  def install
    binding.pry
  end

  private
  
    def crm_payload
      json_payload = CRM_ELEMENT_INSTANCE_BODY[params[:state]]['json_body']
      JSON.generate(json_payload) % instance_hash
    end

    def fd_payload
      json_payload = FD_INSTANCE_BODY
      JSON.generate(json_payload) % {:api_key => 'WMhJrGqFy1qNxMdDLT', :subdomain => 'sumitjagdambacom', :fd_instance_name => "freshdesk_#{current_account.id}" }
    end

    def user_agent
      {:user_agent => request.user_agent}
    end

    def instance_hash
      hash = {}
      CRM_ELEMENT_INSTANCE_BODY[params[:state]]['parameters'].each do |param|
         hash["#{param}".to_sym] = params["#{param}".to_sym]
      end
      hash[:element_name] = "#{params[:state]}_#{current_account.id}"
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
      metadata = {:user_agent => request.user_agent, :element_token => element_token}
      CRM_ELEMENT_INSTANCE_BODY[params[:state]]['objects'].each do |key,obj|
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
      @contact_payload = obj_def_payload( @contact_synced )
      @account_payload = obj_def_payload( @account_synced )
      @contact
    end

    def create_obj_definition
      
      crm_element_object_def
      freshdesk_object_def
    end

    def create_crm_element_object_def
      contact_metadata = {:instance_id => @app_config['element_instance_id'], :object => 'FDContact', :user_agent => request.user_agent}
      account_metadata = {:instance_id => @app_config['element_instance_id'], :object => 'FDCompany', :user_agent => request.user_agent}
      create_instance_object_definition( @contact_payload, contact_metadata )
      create_instance_object_definition( @account_payload, account_metadata )
      create_instance_transformation( crm_element_trans_payload(@contact_payload), contact_metadata )
      create_instance_transformation( crm_element_trans_payload(@account_payload), account_metadata )
    end

    def create_freshdesk_object_def
      contact_metadata = {:instance_id => @app_config['fd_instance_id'], 
      account_metadata = {:instance_id => @app_config['fd_instance_id'], :object => 'FDCompany', :user_agent => request.user_agent}
      create_instance_object_definition( @contact_payload, contact_metadata )
      create_instance_object_definition( @account_payload, account_metadata )
      create_instance_transformation( fd_trans_payload(@contact_payload,'user'), contact_metadata )
      create_instance_transformation( fd_trans_payload(@account_payload,'customer'), account_metadata )
    end

    def update_crm_element_object_def
      contact_metadata = {:instance_id => @app_config['element_instance_id'], :object => 'FDContact', :user_agent => request.user_agent}
      account_metadata = {:instance_id => @app_config['element_instance_id'], :object => 'FDCompany', :user_agent => request.user_agent}
      update_instance_object_definition( @contact_payload, contact_metadata )
      update_instance_object_definition( @account_payload, account_metadata )
      update_instance_transformation( crm_element_trans_payload(@contact_payload), contact_metadata )
      update_instance_transformation( crm_element_trans_payload(@account_payload), account_metadata )
    end

    def update_freshdesk_object_def
      contact_metadata = {:instance_id => @app_config['fd_instance_id'], :object => 'FDContact', :user_agent => request.user_agent}
      account_metadata = {:instance_id => @app_config['fd_instance_id'], :object => 'FDCompany', :user_agent => request.user_agent}
      update_instance_object_definition( @contact_payload, contact_metadata )
      update_instance_object_definition( @account_payload, account_metadata )
      update_instance_transformation( fd_trans_payload(@contact_,'user'), contact_metadata )
      update_instance_transformation( fd_trans_payload(@account_payload,'customer'), account_metadata )
    end

    def obj_def_payload obj_synced
      hash = {}
      arr = Array.new
      obj_synced.each do |obj|
        arr.push({
          'path' => "FD_#{obj['fd_field']}",
          'type' => 'string'                            #what is the use of using the type in cloud elements       
        })
      end
      hash[:fields] = arr
      JSON.generate(hash)
    end

    def crm_element_trans_payload obj_synced
      obj_synced.each do |obj|
        arr.push({
          "path" => "FD_#{obj['fd_field']}",
          "vendorPath" => obj['sf_field']
        })
      end
    end

    def fd_trans_payload obj_synced, fd_obj
      arr = Array.new
      obj_synced.each do |obj|
        arr.push({
          "path" => "FD_#{obj['fd_field']}",
          "vendorPath" => "#{obj}.#{obj['fd_field']}"
        })
      end
    end

    def create_formula_instance
      metadata = {:formula_id => '547', :user_agent => request.user_agent}
      formula_instance(formula_instance_payload, metadata)
    end

    def formula_instance_payload
      json_payload = FORMULA_INSTANCE_BODY
      JSON.generate(json_payload) % {:formula_instance => "Formula_#{@app_config['element']}_#{current_account.id}", :element_instance_id => @app_config['element_instance_id'],:fd_instance_id => @app_config['fd_instance_id']}
    end

    def load_installed_app
      @installed_app = current_account.installed_applications.find_by_application_id(app.id)
      @app_config = @installed_app.configs[:inputs]
      unless @installed_app
        flash[:error] = t(:'flash.application.not_installed')
        redirect_to integrations_applications_path
      end
    end

end