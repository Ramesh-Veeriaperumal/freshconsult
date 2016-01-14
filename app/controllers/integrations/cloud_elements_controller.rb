class Integrations::CloudElementsController < ApplicationController

  skip_before_filter :check_privilege, :verify_authenticity_token
  before_filter :build_installed_app, :only => [:oauth_url]
  before_filter :load_installed_app, :only => [:edit, :update]
  before_filter :get_app_configs, :only => [:install]
  before_filter :handle_ce_work, :only => [:install,:update]
  

  def oauth_url
    metadata = {:element => params[:state], :user_agent => request.user_agent}
    response = service_obj({}, metadata).receive(:oauth_url)
    redirect_url = response['oauthUrl']
    redirect_to redirect_url
  end

  # def install
  #   formula_instance
  #   @installed_app = current_account.installed_applications.build(:application => app)
  #   @installed_app.configs = { :inputs => {} }
  #   @installed_app.configs[:inputs] = @app_config
  #   @installed_app.set_configs get_metadata_fields
  #   @installed_app.save!
  #   flash[:notice] = t(:'flash.application.install.success')
  #   redirect_to integrations_applications_path
  # rescue => e
  #   NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in installing the application : #{e.message}"}})
  #   flash[:error] = t(:'flash.application.install.error')
  #   redirect_to integrations_applications_path
  # end

  def edit
    @action = 'update'
    @sync_type = SYNC_TYPE
    @salesforce_config = {}
    @salesforce_config['enble_sync'] = @app_config['enble_sync']
    @salesforce_config['crm_sync_type'] = @app_config['enble_sync']
    construct_synced_contacts
    settings(@app_config['element_token'])
  end

  # def update
  #   @installed_app.set_configs get_metadata_fields
  #   @installed_app.save!
  #   flash[:notice] = t(:'flash.application.install.succes')
  #   redirect_to integrations_applications_path
  # rescue => e
  #   NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in installing the application : #{e.message}"}})
  #   flash[:error] = t(:'flash.application.install.error')
  #   redirect_to integrations_applications_path
  # end

  private

    def build_installed_app
      @installed_app = current_account.installed_applications.build(:application => app )
      @installed_app.configs = { :inputs => {} }
    end

    def app
      Integrations::Application.find_by_name(Integrations::CloudElements::ElementConstant::APP_NAMES[params[:state].to_sym])
    end

    def service_obj payload, metadata
       @cloud_elements_obj = IntegrationServices::Services::CloudElementsService.new(@installed_app, payload, metadata)
    end

    def create_element_instance payload, metadata
      service_obj(payload, metadata).receive(:create_element_instance)
    end

    def delete_element_instance payload, metadata
      service_obj(payload, metadata).receive(:delete_element_instance)
    end

    def create_instance_object_definition payload, metadata
      service_obj(payload, metadata).receive(:create_instance_object_definition)
    end

    def update_instance_object_definition payload, metadata
      service_obj(payload, metadata).receive(:update_instance_object_definition)
    end

    def create_instance_transformation payload, metadata 
      service_obj(payload, metadata).receive(:create_instance_transformation)
    end

    def update_instance_transformation payload, metadata
      service_obj(payload, metadata).receive(:update_instance_transformation)
    end

    def create_formula_instance payload, metadata
      service_obj(payload, metadata).receive(:create_formula_instance)
    end

    def delete_formula_instance payload, metadata
      service_obj(payload, metadata).receive(:delete_formula_instance)
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