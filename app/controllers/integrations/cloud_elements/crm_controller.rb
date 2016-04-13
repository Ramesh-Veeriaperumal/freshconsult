class Integrations::CloudElements::CrmController < Integrations::CloudElementsController
  include Integrations::CloudElements::Crm::Constant
  before_filter :verify_authenticity, :only => [:instances, :install, :edit, :update]
  before_filter :build_installed_app, :only => [:instances]
  before_filter :load_installed_app, :only => [:install, :edit, :update]
  before_filter :create_obj_transformation, :only => [:install]
  before_filter :update_obj_transformation, :only => [:update]
  before_filter :update_formula_inst, :only => [:install, :update]
  
  def instances
    el_response = create_element_instance( crm_payload, @metadata )
    fd_response = create_element_instance( fd_payload, @metadata )
    fetch_metadata_fields(el_response['token'])
    formula_resp = create_formula_inst(el_response['id'], fd_response['id'])
    app_configs = get_app_configs(el_response['token'], el_response['id'], fd_response['id'], formula_resp['id'])
    @installed_app.configs[:inputs].merge!(app_configs)
    @installed_app.save!
    @action = 'install'
    flash[:notice] = t(:'flash.application.install.cloud_element_success')
    render_settings
  rescue => e
    binding.pry
    if params[:state].eql? "dynamicscrm" and el_response.nil?
      flash[:error] = "Please provide a valid Organisation URL"
      redirect_to "/integrations/dynamicscrm/settings?state=dynamicscrm&dynamicscrm_url=#{params["dynamicscrm_url"]}" #configs=#{CGI.escape params["configs"]}&
    else
      [el_response, fd_response].each do |response|
        delete_element_instance_error @installed_app, request.user_agent, response['id'] if response.present?
      end
      delete_formula_instance_error @installed_app, request.user_agent, formula_resp['id'] if formula_resp.present?
      NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in installing the application : #{e.message}"}})
      flash[:error] = t(:'flash.application.update.error')
      redirect_to integrations_applications_path
    end
  end

  def install
    @installed_app.set_configs get_metadata_fields
    @installed_app.save!
    flash[:notice] = t(:'flash.application.update.success')
    redirect_to integrations_applications_path
  rescue => e
    NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in installing the application : #{e.message}"}})
    flash[:error] = t(:'flash.application.update.error')
    redirect_to integrations_applications_path
  end

  def edit
    binding.pry
    @action = 'update'
    fetch_metadata_fields(@app_config['element_token'])
    @element_config['enble_sync'] = @app_config['enble_sync']
    default_mapped_fields
    construct_synced_contacts
    render_settings
  rescue => e
    NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in installing the application : #{e.message}"}})
    flash[:error] = t(:'flash.application.update.error')
    redirect_to integrations_applications_path
  end

  def update
    @installed_app.set_configs get_metadata_fields
    @installed_app.save!
    flash[:notice] = t(:'flash.application.update.success')
    redirect_to integrations_applications_path
  rescue => e
    NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in updating the application : #{e.message}"}})
    flash[:error] = t(:'flash.application.update.error')
    redirect_to integrations_applications_path
  end

  def event_notification
    render :json => {:status => '200 Ok'}
  end

  private

    def element
      APP_NAMES[params[:state].to_sym]
    end
  
    def crm_payload
      json_payload = File.read("lib/integrations/cloud_elements/crm/#{element}/#{element}.json")
      json_payload % instance_hash
    end

    def fd_payload
      json_payload = JSON.parse(File.read("lib/integrations/cloud_elements/freshdesk.json"))
      event_poller_config = File.read("lib/integrations/cloud_elements/event_poller.json")
      json_payload['configuration']['event.poller.configuration'] = event_poller_config
      api_key = current_user.single_access_token
      subdomain = current_account.domain
      JSON.generate(json_payload) % {:api_key => api_key, :subdomain => "bb5c49bb", :fd_instance_name => "freshdesk_#{element}_#{current_account.id}" }
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

    def fetch_metadata_fields(element_token)
      crm_element_metadata_fields(element_token)
      fd_metadata_fields
    end

    def crm_element_metadata_fields(element_token)
      @element_config = Hash.new
      # @element_config['features']= current_account.features?(:cloud_elements_crm_sync)
      if element == 'salesforce'
        @element_config = JSON.parse $redis_others.get("cloud_elements_salesforce:#{current_account.id}")
        #removing the custom fields that we will be syncing from the customers view
        @element_config["contact_fields"].delete("FD_ContactId__c")
        @element_config["contact_fields_types"].delete("FD_ContactId")
        @element_config["account_fields"].delete("FD_AccountId__c")
        @element_config["account_fields_types"].delete("FD_AccountId")
      else
        metadata = @metadata.merge({ :element_token => element_token })
        constant_file = JSON.parse(File.read("lib/integrations/cloud_elements/crm/#{element}/constant.json"))
        constant_file['objects'].each do |key, obj|
          metadata[:object] = obj
          element_metadata = service_obj({},metadata).receive("#{key}_metadata".to_sym)
          hash = map_fields( element_metadata )
          @element_config["#{key}_fields"] = hash['fields_hash']
          @element_config["#{key}_fields_types"] = hash['data_type_hash']
        end
      end

    end

    def fd_metadata_fields
      contact_metadata = current_account.contact_form.fields
      company_metadata = current_account.company_form.fields
      contact_hash = fd_fields_hash( contact_metadata, "contact" )
      account_hash = fd_fields_hash( company_metadata, "company" )
      @element_config['element'] = element
      @element_config['fd_contact'] = contact_hash['fields_hash']
      @element_config['fd_contact_types'] = contact_hash['data_type_hash']
      @element_config['fd_company'] = account_hash['fields_hash']
      @element_config['fd_company_types'] = account_hash['data_type_hash']
      # @element_config['fd_validator'] = FD_VALIDATOR
    end

    def map_fields(metadata)
      fields_hash = {}
      data_type_hash = {}
      metadata['fields'].each do |field|
        label = field['vendorDisplayName'] || field['vendorPath']
        fields_hash[field['vendorPath']] = label
        data_type_hash[label] = field['type']
      end
      {'fields_hash' => fields_hash, 'data_type_hash' => data_type_hash }
    end

    def fd_fields_hash(object, type)
      fields_hash = {}
      data_type_hash = {}
      if type.eql? "contact"
        data_types = CONTACT_TYPES
      else
        data_types = COMPANY_TYPES
      end
      #To remove those custom fields that we will be syncing from the customers view
      custom_fields = ["cf_sf_accountid", "cf_sf_contactid"]
      object.each do |field|
        unless custom_fields.include? field[:name]
          fields_hash[field[:name]] = field[:label]
          data_type_hash[field[:label]] = data_types[field[:field_type].to_s]
        end
      end
      {'fields_hash' => fields_hash, 'data_type_hash' => data_type_hash }
    end

    def render_settings
      render :template => "integrations/applications/crm_fields"
    rescue => e
      NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in installing the application : #{e.message}"}})
      flash[:error] = t(:'flash.application.update.error')
      redirect_to integrations_applications_path
    end

    def get_app_configs( element_token, element_instance_id, fd_instance_id, formula_instance_id )
      element_config = default_mapped_fields
      config_hash = Hash.new
      config_hash['element_token'] = element_token
      config_hash['element_instance_id'] = element_instance_id
      config_hash['fd_instance_id'] = fd_instance_id
      config_hash['crm_to_helpdesk_formula_instance'] = formula_instance_id
      config_hash['enble_sync'] = nil
      binding.pry
      element_config['objects'].each do |object|
        if @installed_app.configs[:inputs]["#{object}s"].present?
          #dynamics
          config_hash["#{object}_fields"] = @installed_app.configs[:inputs]["#{object}s"].join(",")
          config_hash["#{object}_labels"] = @installed_app.configs[:inputs]["#{object}_labels"]
          @installed_app.configs[:inputs].delete("#{object}s")
        else
          config_hash["#{object}_fields"] = element_config['default_fields'][object].join(",")
          config_hash["#{object}_labels"] = element_config['default_labels'][object].join(",")
        end 
      end
      # config_hash['contact_fields'] = element_config['default_fields']['contact'].join(",")
      # config_hash['account_fields'] = element_config['default_fields']['account'].join(",")
      # config_hash['lead_fields'] = element_config['default_fields']['lead'].join(",")
      # config_hash['contact_labels'] = element_config['default_labels']['contact'].join(",")
      # config_hash['account_labels'] = element_config['default_labels']['account'].join(",")
      # config_hash['lead_labels'] = element_config['default_labels']['lead'].join(",")
      config_hash['companies'] = get_selected_field_arrays(element_config['existing_companies'])
      config_hash['contacts'] = get_selected_field_arrays(element_config['existing_contacts'])
      case element
      when "salesforce"
        config_hash['opportunity_view'] = "0"
      when "dynamicscrm"
        config_hash['dynamicscrm_url'] = params["dynamicscrm_url"]
      end
      config_hash
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
    rescue => e
      NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in installing the application : #{e.message}"}})
      flash[:error] = t(:'flash.application.update.error')
      redirect_to integrations_applications_path
    end

    def update_obj_transformation
      get_synced_objects
      @contact_metadata = @metadata.merge({:object => 'fdContact', :method => 'put'})
      @account_metadata = @metadata.merge({:object => 'fdCompany', :method => 'put'})
      crm_element_object_transformation
      freshdesk_object_transformation
    rescue => e
      NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in updating the application : #{e.message}"}})
      flash[:error] = t(:'flash.application.update.error')
      redirect_to integrations_applications_path
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
          'path' => "FD_slave_#{obj['fd_field']}",
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
          "path" => "FD_slave_#{obj['fd_field']}",
          "vendorPath" => obj['sf_field']
        })
      end
      parse_trans_payload( arr, obj_name)
    end

    def fd_trans_payload obj_synced, fd_obj, obj_name
      arr = Array.new
      obj_synced.each do |obj|
        arr.push({
          "path" => "FD_slave_#{obj['fd_field']}",
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

    def create_formula_inst( element_instance_id, fd_instance_id )
      formula_id = CRM_TO_HELPDESK_FORMULA_ID[element.to_sym]
      metadata = @metadata.merge({:formula_id => formula_id})
      payload = formula_instance_payload( "#{element}=>freshdesk:#{current_account.id}", element_instance_id, fd_instance_id )
      create_formula_instance(payload, metadata)
    rescue => e
      NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in installing the application : #{e.message}"}})
      flash[:error] = t(:'flash.application.install.error')
      redirect_to integrations_applications_path and return 
    end

    def update_formula_inst
      formula_id = CRM_TO_HELPDESK_FORMULA_ID[element.to_sym]
      metadata = @metadata.merge({:formula_id => formula_id, :formula_instance_id => @app_config['crm_to_helpdesk_formula_instance']})
      payload = formula_instance_payload( "#{element}=>freshdesk:#{current_account.id}", @app_config['element_instance_id'], @app_config['fd_instance_id'])
      update_formula_instance(payload, metadata)
    rescue => e
      NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in installing the application : #{e.message}"}})
      flash[:error] = t(:'flash.application.update.error')
      redirect_to integrations_applications_path and return 
    end

    def formula_instance_payload instance_name, source, target
      json_payload = File.read("lib/integrations/cloud_elements/formula_instance.json")
      active = params[:enble_sync] == "on"
      json_payload % {:formula_instance => instance_name, :source => source ,:target => target, :active => active}
    end

    def get_metadata_fields
      config_hash = Hash.new 
      config_hash['enble_sync'] = params[:enble_sync]
      config_hash['contact_fields'] = params[:contacts].join(",") unless params[:contacts].nil?
      config_hash['lead_fields'] = params[:leads].join(",") unless params[:leads].nil?
      config_hash['account_fields'] = params[:accounts].join(",") unless params[:accounts].nil?
      config_hash['contact_labels'] = params['contact_labels'] unless params[:contacts].nil?
      config_hash['lead_labels'] = params['lead_labels'] unless params[:leads].nil?
      config_hash['account_labels'] = params['account_labels'] unless params[:accounts].nil?
      config_hash = get_opportunity_params config_hash if element.eql? "salesforce"
      config_hash['companies'] = get_selected_field_arrays(params[:inputs][:companies])
      config_hash['contacts'] = get_selected_field_arrays(params[:inputs][:contacts])
      config_hash
    end

    def get_opportunity_params(config_hash)
      config_hash['opportunity_view'] = params[:opportunity_view][:value]
      if config_hash['opportunity_view'].to_bool
        config_hash['opportunity_fields'] = params[:opportunities].join(",") unless params[:opportunities].nil?
        config_hash['opportunity_labels'] = params[:opportunity_labels]
        config_hash['agent_settings'] = params[:agent_settings][:value]
        # if config_hash['agent_settings'].to_bool
        #   metadata = @metadata.merge({ :object => 'Opportunity' })
        #   config_hash["opportunity_stage_choices"] = service_obj({}, metadata).receive(:opportunity_stage_field)
        # else
        #   @installed_app.configs[:inputs].delete("opportunity_stage_choices")
        # end
      else
        opportunity_configs = [ "opportunity_fields", "opportunity_labels", "agent_settings", "opportunity_stage_choices" ]
        @installed_app.configs[:inputs] = @installed_app.configs[:inputs].except(*opportunity_configs)
      end
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
      @element_config['existing_contacts'] = Array.new
      contact_synced = @installed_app.configs_contacts
      account_synced = @installed_app.configs_companies
      contact_synced['fd_fields'].each_with_index do |fd_field, index|
        @element_config['existing_contacts'].push({'fd_field' => fd_field, 'sf_field' => contact_synced['sf_fields'][index]})
      end
      # @installed_app.configs_contacts = arr
      @element_config['existing_companies'] = []
      account_synced['fd_fields'].each_with_index do |fd_field, index|
        @element_config['existing_companies'].push({'fd_field' => fd_field, 'sf_field' => account_synced['sf_fields'][index]})
      end
      # @installed_app.configs_companies = arr
    end

    def default_mapped_fields
      file = JSON.parse(File.read("lib/integrations/cloud_elements/crm/#{element}/constant.json"))
      @element_config['existing_companies'] = file['existing_companies']
      @element_config['existing_contacts'] = file['existing_contacts']
      @element_config['default_fields'] = file['default_fields']
      @element_config['default_labels'] = file['default_labels']
      @element_config['element_validator'] = file['validator']
      @element_config['fd_validator'] = file['fd_validator']
      @element_config['objects']= file['objects'].keys
      @element_config
    end

    def self.destroy_ce_instances( installed_app, user_agent )
      installed_app_configs = installed_app.configs[:inputs]
      element_instance_id = installed_app_configs['element_instance_id']
      fd_instance_id = installed_app_configs['fd_instance_id']
      formula_instance_id = installed_app_configs['crm_to_helpdesk_formula_instance']
      app_name = installed_app.application.name
      formula_id = CRM_TO_HELPDESK_FORMULA_ID[app_name.to_sym]
      metadata = {:user_agent => user_agent}
      Integrations::CloudElementsController.delete_formula_instance(installed_app, {}, metadata.merge({:formula_id => formula_id, :formula_instance_id => formula_instance_id}))
      Integrations::CloudElementsController.delete_element_instance(installed_app, {}, metadata.merge({ :element_instance_id => element_instance_id }))
      Integrations::CloudElementsController.delete_element_instance(installed_app, {}, metadata.merge({ :element_instance_id => fd_instance_id }))
    end

    def build_configs
      arr =[] 
      params.each do |key, value|
        arr << "#{key}=#{value}"
      end
      arr.join("&")
    end

    def delete_element_instance_error installed_app, user_agent, element_instance_id
      app_name = installed_app.application.name
      metadata = {:user_agent => user_agent}
      Integrations::CloudElementsController.delete_element_instance(installed_app, {}, metadata.merge({ :element_instance_id => element_instance_id }))
    end

    def delete_formula_instance_error installed_app, user_agent, formula_instance_id
      app_name = installed_app.application.name
      formula_id = CRM_TO_HELPDESK_FORMULA_ID[app_name.to_sym]
      metadata = {:user_agent => user_agent}
      Integrations::CloudElementsController.delete_formula_instance(installed_app, {}, metadata.merge({:formula_id => formula_id, :formula_instance_id => formula_instance_id}))
    end

end