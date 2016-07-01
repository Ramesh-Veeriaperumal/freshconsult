class Integrations::FullcontactController < Admin::AdminController

  include Integrations::Fullcontact::Constants

  APP_NAME = Integrations::Constants::APP_NAMES[:fullcontact]

  skip_before_filter :check_privilege, :only => [:callback]
  before_filter :load_installed_app, :only => [:new, :callback, :edit]
  before_filter :check_installed_app, :only => [:new]
  before_filter :set_element_configs, :only => [:new, :edit]

  def new
    render_settings
  end

  def callback
    begin
      Thread.current[:http_user_agent] = "Freshdesk"
      model_name, webhook_id = params["webhookId"].split(":")
      params["result"] = JSON.parse(params["result"]) if model_name.eql? "contact"
      if params["result"]["status"] == 200
        payload = { :result => params["result"],
                    "#{model_name}_id".to_sym => webhook_id,
                    :model_name => model_name }
        service_obj = IntegrationServices::Services::FullcontactService.new(@installed_app, payload)
        service_obj.receive(:webhook_response)
      end
    ensure
      Thread.current[:http_user_agent] = nil
    end
    render :json => 200
  end

  def edit
    @api_key = @installed_app["configs"][:inputs]["api_key"] if @installed_app.present?
    render_settings
  end

  def update
    @installed_app = Integrations::Application.install_or_update("fullcontact", current_account.id, configs_hash)
    if @installed_app.va_rules.empty?
      service_object.receive(:install)
      flash[:notice] = t(:'flash.application.install.success')
    else
      flash[:notice] = t(:'flash.application.update.success')
    end
    redirect_to integrations_applications_path
  end

  private

    def set_element_configs
      @element_config = Hash.new
      contact_metadata = current_account.contact_form.fields
      company_metadata = current_account.company_form.fields
      contact_hash = fd_contact_fields_hash(contact_metadata)
      company_hash = fd_company_fields_hash(company_metadata)
      @element_config['fd_contact'] = contact_hash["hash"]
      @element_config['fd_contact_types'] = contact_hash["data_type_hash"]
      @element_config['fc_social_profile'] = FC_CONTACT_SOCIAL_PROFILES
      @element_config['fd_company'] = company_hash["hash"]
      @element_config['fd_company_types'] = company_hash["data_type_hash"]
      @element_config["fc_contact"] = FC_CONTACT_FIELDS_HASH
      @element_config["fc_contact_types"] = FC_CONTACT_DATA_TYPES
      @element_config["fc_company"] = FC_COMPANY_FIELDS_HASH
      @element_config["fc_company_types"] = FC_COMPANY_DATA_TYPES
      @element_config["existing_contacts"] = selected_contact_fields
      @element_config["existing_companies"] = selected_company_fields
      @element_config['fd_validator'] = FD_VALIDATOR
      @element_config['fc_validator'] = FC_VALIDATOR
    end

    def load_installed_app
      @installed_app = current_account.installed_applications.with_name(APP_NAME).first
    end

    def service_object
      @fullcontact_object ||= IntegrationServices::Services::FullcontactService.new(@installed_app)
    end

    def configs_hash
      company = {"fc_field" => [], "fd_field" => []}
      params["configs"]["inputs"]["companies"].each do |field_pair|
        company["fc_field"] << field_pair["fc_field"]
        company["fd_field"] << field_pair["fd_field"]
      end
      contact = {"fc_field" => [], "fd_field" => []}
      params["configs"]["inputs"]["contacts"].each do |field_pair|
        contact["fc_field"] << field_pair["fc_field"]
        contact["fd_field"] << field_pair["fd_field"]
      end

      {
        "api_key" => params["configs"]["api_key"],
        "contact" => contact,
        "company" => company
      }
    end

    def render_settings
       render :template => "integrations/applications/fullcontact/settings",
              :layout => 'application' and return
    end

    def fd_contact_fields_hash(object)
      hash = {"avatar" => "Avatar"}
      data_type_hash = {"Avatar" => "avatar"}
      object.each do |field|
        if FD_CONTACT_FIELD_TYPES.include? field[:field_type]
          hash[field[:name]] = field[:label] 
          data_type_hash[field[:label]] = FD_CONTACT_TYPES[field[:field_type]]
        end
      end
      {"hash" => hash, "data_type_hash" => data_type_hash}
    end

    def fd_company_fields_hash(object)
      hash = {}
      data_type_hash = {}
      object.each do |field|
        if FD_COMPANY_FIELD_TYPES.include? field[:field_type]
          hash[field[:name]] = field[:label] 
          data_type_hash[field[:label]] = FD_COMPANY_TYPES[field[:field_type]]
        end
      end
      {"hash" => hash, "data_type_hash" => data_type_hash}
    end

    def selected_contact_fields
      if @installed_app.present?
        fc_fields = @installed_app["configs"][:inputs]["contact"]["fc_field"]
        fd_fields = @installed_app["configs"][:inputs]["contact"]["fd_field"]
        selected_fields = construct_selected_fields_array fc_fields, fd_fields
      else
        selected_fields = SELECTED_CONTACT_FIELDS
      end
      selected_fields
    end

    def selected_company_fields
      if @installed_app.present?
        fc_fields = @installed_app["configs"][:inputs]["company"]["fc_field"]
        fd_fields = @installed_app["configs"][:inputs]["company"]["fd_field"]
        selected_fields = construct_selected_fields_array fc_fields, fd_fields
      else
        selected_fields = SELECTED_COMPANY_FIELDS
      end
      selected_fields
    end

    def construct_selected_fields_array fc_fields, fd_fields
      selected_fields = []
        fd_fields.each_with_index do |val, index|
          selected_fields << {"fd_field" => val, "fc_field" => fc_fields[index]}
        end
      selected_fields
    end

    def check_installed_app
      if @installed_app.present?
        flash[:notice] = t(:'flash.application.already') 
        redirect_to integrations_applications_path
      end 
    end
end
