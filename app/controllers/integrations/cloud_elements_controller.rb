class Integrations::CloudElementsController < ApplicationController
  include Integrations::CloudElements::Constant

  skip_before_filter :check_privilege, :verify_authenticity_token
  before_filter :build_installed_app, :only => [:oauth_url,:instances]
  before_filter :load_installed_app, :only => [:edit, :update]
  before_filter :get_app_configs, :only => [:install]
  before_filter :handle_ce_work, :only => [:install,:update]
  

  def oauth_url
    metadata = {:element => params[:state], :user_agent => request.user_agent}
    response = service_obj({}, metadata).receive(:oauth_url)
    redirect_url = response['oauthUrl']
    redirect_to redirect_url
  end

  def instances
    el_response = element_instance
    fd_response = fd_instance
    set_redis_keys({ :element => params[:state], :element_token => el_response['token'], :element_instance_id => el_response['id'], :fd_instance_id => fd_response['id']})
    fetch_metadata_fields
  end

  def install
    formula_instance
    @installed_app = current_account.installed_applications.build(:application => app)
    @installed_app.configs = { :inputs => {} }
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
    @sync_type = SYNC_TYPE
    @salesforce_config = {}
    @salesforce_config['enble_sync'] = @app_config['enble_sync']
    @salesforce_config['crm_sync_type'] = @app_config['enble_sync']
    construct_synced_contacts
    settings(@app_config['element_token'])
  end

  def update
    @installed_app.set_configs get_metadata_fields
    @installed_app.save!
    flash[:notice] = t(:'flash.application.install.succes')
    redirect_to integrations_applications_path
  rescue => e
    NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in installing the application : #{e.message}"}})
    flash[:error] = t(:'flash.application.install.error')
    redirect_to integrations_applications_path
  end

  private

    def build_installed_app
      @installed_app = current_account.installed_applications.build(:application => @application)
      @installed_app.configs = { :inputs => {} }
    end

    def service_obj(payload, metadata)
       @cloud_elements_obj ||= IntegrationServices::Services::CloudElementsService.new(@installed_app, payload, metadata)
    end

    def element_instance
      payload = JSON.generate(CRM_ELEMENT_INSTANCE_BODY[params[:state]]['json_body']) % instance_hash
      metadata = {:user_agent => request.user_agent}
      service_obj(payload, metadata).receive(:create_instances)
    end

    def fd_instance
      payload = JSON.generate(FD_INSTANCE_BODY) % {:api_key => 'WMhJrGqFy1qNxMdDLT', :subdomain => 'sumitjagdambacom'}
      metadata = {:user_agent => request.user_agent}
      service_obj(payload, metadata).receive(:create_instances)
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

    def fetch_metadata_fields
    end

    def handle_ce_work
      @contact_synced = params[:inputs][:contacts]
      @account_synced = params[:inputs][:companies]
      begin_obj_definition
      begin_transformation
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

    # def element_instance  
    #   @action = 'install'
    #   @sync_type = SYNC_TYPE
    #   @salesforce_config = {}
    #   settings
    # end

    

    def settings
      freshdesk_fields = fd_fields
      @salesforce_config['fd_contact'] = freshdesk_fields['fd_contact']
      @salesforce_config['fd_company'] = freshdesk_fields['fd_company']
      ELEMENT_INSTANCE_BODY[params[:state]]['objects'].each do |key,obj|
        metadata = fetch_metadata_fields(obj, element_token)
        @salesforce_config["#{key}_fields"] = map_fields(metadata)
      end
      render :template => "integrations/applications/salesforce_fields"
    rescue => e
      NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in installing the application : #{e.message}"}})
      flash[:error] = t(:'flash.application.install.error')
      redirect_to integrations_applications_path
    end

    def fetch_metadata_fields(object_name)
      params[:method] = GET
      params[:rest_url] = "hubs/crm/objects/#{object_name}/metadata"
      @req_params[:auth_header] = AUTH_HEADER + "," + "Element #{element_token}"
      params[:body] = ''
      response = @hrp.fetch_using_req_params(params,@req_params)
    end

    def map_fields(metadata)
      metadata = JSON.parse(metadata[:text])['fields']
      hash = {}
      metadata.each do |field|
        hash[field['vendorPath']] = field['vendorDisplayName'] || field['vendorPath']
      end
      hash
    end

    def fd_fields
      fd_fields = {}
      fd_contact = current_account.contact_form.fields
      fd_company = current_account.company_form.fields
      fd_fields['fd_contact'] = fd_fields_hash(fd_contact)
      fd_fields['fd_company'] = fd_fields_hash(fd_company)
      fd_fields
    end

    def fd_fields_hash(object)
      hash = {}
      object.each do |field|
        hash[field[:name]] = field[:label]
      end
      hash
    end

    def app
      Integrations::Application.find_by_name(Integrations::Constants::APP_NAMES[:salesforce])
    end

    def get_app_configs
      key_options = { :account_id => current_account.id, :provider => app.name}
      kv_store = Redis::KeyValueStore.new(Redis::KeySpec.new(Redis::RedisKeys::APPS_AUTH_REDIRECT_OAUTH, key_options))
      kv_store.group = :integration
      @app_config = JSON.parse(kv_store.get_key)
    end

    def begin_obj_definition
      object_definition(@app_config['element_instance_id'],'FreshContact',@contact_synced)
      object_definition(@app_config['element_instance_id'],'FreshCompany',@account_synced)
      object_definition(@app_config['fd_instance_id'],'FreshContact',@contact_synced)
      object_definition(@app_config['fd_instance_id'],'FreshCompany',@account_synced)
    end

    def object_definition(instance_id,ce_obj_name,obj_synced_fields)
      params[:method] = (@installed_app.present?) ? PUT : POST
      params[:rest_url] = "instances/#{instance_id}/objects/#{ce_obj_name}/definitions"
      @req_params[:auth_header] = AUTH_HEADER
      params[:content_type] = CONTENT_TYPE
      params[:body] = obj_definition_body(obj_synced_fields)
      @hrp.fetch_using_req_params(params,@req_params)
    end

    def obj_definition_body(obj_synced_fields)
      hash = {}
      arr = Array.new
      obj_synced_fields.each do |obj|
        arr.push({
          'path' => "FD_#{obj['fd_field']}",
          'type' => 'string'
        })
      end
      hash[:fields] = arr
      JSON.generate(hash)
    end

    def begin_transformation
      transformation(@app_config['element'],@app_config['element_instance_id'],'FreshContact',@contact_synced,'Contact')
      transformation(@app_config['element'],@app_config['element_instance_id'],'FreshCompany',@account_synced,'Account')
      transformation('freshdesk',@app_config['fd_instance_id'],'FreshContact',@contact_synced,'contacts')
      transformation('freshdesk',@app_config['fd_instance_id'],'FreshCompany',@account_synced,'accounts')
    end

    def transformation(element,instance_id,ce_obj_name, obj_synced_fields, obj_name)
      params[:rest_url] = "instances/#{instance_id}/transformations/#{ce_obj_name}"
      params[:body] = element_transformation_body(element, obj_synced_fields, obj_name)
      @hrp.fetch_using_req_params(params,@req_params)
    end

    def element_transformation_body(element, obj_synced_fields, obj)
      arr = Array.new
      if element == 'freshdesk'
        fd_obj = (obj == 'contacts' ? 'user' : 'customer')
        obj_synced_fields.each do |obj|
            arr.push({
              "path" => "FD_#{obj['fd_field']}",
              "vendorPath" => "#{fd_obj}.#{obj['fd_field']}"
            })
        end
      else
        obj_synced_fields.each do |obj|
            arr.push({
              "path" => "FD_#{obj['fd_field']}",
              "vendorPath" => obj['sf_field']
            })
        end
      end
      TRANSFORMATION_BODY['fields'] = arr
      JSON.generate(TRANSFORMATION_BODY) % {:object_name => obj}
    end

    def formula_instance
      params[:rest_url] = 'formulas/547/instances'
      params[:body] = JSON.generate(FORMULA_INSTANCE_BODY) % {:formula_instance => "Formula_#{@app_config['element']}_#{current_account.id}", :element_instance_id => @app_config['element_instance_id'],:fd_instance_id => @app_config['fd_instance_id']}
      @hrp.fetch_using_req_params(params,@req_params)
    end

    def load_installed_app
      @installed_app = current_account.installed_applications.find_by_application_id(app.id)
      @app_config = @installed_app.configs[:inputs]
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

end