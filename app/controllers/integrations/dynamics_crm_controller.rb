class Integrations::DynamicsCrmController < ApplicationController
  include Integrations::DynamicsCrm::CrmUtil
  include Integrations::DynamicsCrm::ApiUtil
  include Integrations::Constants

  before_filter :load_settings_config, :only => [ :widget_data, :fields_update, :edit ]
  before_filter :load_fields, :only => [:edit]

  def settings
    render_settings
  end

  def edit
    render_fields
  end

  def settings_update
    dyn_client = dynamics_client(construct_client_params, params["configs"]["contact_email"])
    if dyn_client["status"] != "failure"
      error_message = verify_settings_data(dyn_client)
      if error_message.present?
        flash.now[:error] = error_message
        render_settings
      else
        @installed_app = Integrations::Application.install_or_update("dynamicscrm", current_account.id, config_hash)
        render_fields
      end
    else
      flash.now[:error] = "#{t(:'integrations.dynamicscrm.form.error')}"
      render_settings
    end
  end

  def fields_update
    CRM_MODULE_TYPES.each do |m_type|
      label_key = "#{m_type}_labels"
      field_key = "#{m_type}s"
      @installed_app["configs"][:inputs][label_key] = params[label_key] unless params[label_key].blank?
      @installed_app["configs"][:inputs][field_key] = params[field_key] unless params[field_key].blank?
    end
    flash[:notice] = @installed_app.save! ? t(:'flash.application.install.success') : t(:'flash.application.install.failure')
    redirect_to :controller=> 'applications', :action => 'index'
  end

  def widget_data
    data_json = nil
    dyn_client = dynamics_client(construct_client_params)
    if dyn_client["status"] != "failure"
      data_arr = modules_raw_data(@decrypted_password, dyn_client["client_obj"], params["email"])
      data_json = data_arr.blank? ? api_error : admin_config_filter(data_arr, @installed_app["configs"][:inputs])
    else
      data_json = {"error" => "Could not authenticate dynamics client"}
    end
    render :json => data_json
  end

  private
    def load_settings_config
      @installed_app = current_account.installed_applications.with_name("dynamicscrm").first
      unless @installed_app.blank?
        @instance_type = @installed_app["configs"][:inputs]["instance_type"]
        @domain_user_email = @installed_app["configs"][:inputs]["domain"]
        @decrypted_password = @installed_app.configsdecrypt_password
        @organization_name = @installed_app["configs"][:inputs]["organization_name"]
        @end_point = @installed_app["configs"][:inputs]["endpoint"]
        @login_url = @installed_app["configs"][:inputs]["loginurl"]
        @region = @installed_app["configs"][:inputs]["region"]
      end
    end

    def load_fields
      @fields = {} # @fields is populated in the function verify_email_and_populate_fields
      client_arr = dynamics_client(construct_client_params)
      CRM_MODULE_TYPES.each do |m_type|
        email = @installed_app["configs"][:inputs]["#{m_type}_email"]
        verify_email_and_populate_fields(client_arr["client_obj"], m_type, email) unless email.blank?
      end
    end

    def construct_client_params
      client_params = {}
      client_params["instance_type"] = @installed_app.blank? ? params["configs"]["instance_type"] : @instance_type
      client_params["domain_user_email"] = @installed_app.blank? ? params["configs"]["domain"] : @domain_user_email
      client_params["decrypted_password"] = @installed_app.blank? ? params["configs"]["password"] : @decrypted_password
      client_params["organization_name"] = @installed_app.blank? ? params["configs"]["organization_name"] : @organization_name
      client_params["end_point"] = @installed_app.blank? ? params["configs"]["endpoint"] : @end_point
      client_params["login_url"] = @installed_app.blank? ? params["configs"]["login_url"] : @login_url_str
      client_params["region"] = @installed_app.blank? ? params["configs"]["region"] : @region
      client_params
    end

    def modules_raw_data decrypted_password, dyn_client, req_email
      result_data = []
      CRM_MODULE_TYPES.each do |m_type|
        email = @installed_app["configs"][:inputs]["#{m_type}_email"]
        result_data.push(dynamics_module_data(dyn_client, m_type, req_email, gem_raw_data=true)) unless email.blank?
      end
      result_data
    end

    def config_hash
      hash = { "instance_type" => params["configs"]["instance_type"], "domain" => params["configs"]["domain"],
               "password" => params["configs"]["password"], "organization_name" => params["configs"]["organization_name"],
               "endpoint" => params["configs"]["endpoint"], "loginurl" => params["configs"]["login_url"],
               "region" => params["configs"]["region"]
             }
      CRM_MODULE_TYPES.each do |m_type|
        hash["#{m_type}_email"] = params["configs"]["#{m_type}_email"]
      end
      hash
    end

    def verify_settings_data dynamics_client
      error_message = ""
      CRM_MODULE_TYPES.each do |m_type|
        email = params["configs"]["#{m_type}_email"]
        unless email.blank?
          client_obj = dynamics_client["client_obj"]
          result_type = verify_email_and_populate_fields(client_obj, m_type, email)
          error_message += "#{email} #{t(:'integrations.dynamicscrm.form.entity_error')} #{m_type}. \n" if result_type == "failure"
        end
      end
      error_message
    end

    def verify_email_and_populate_fields client, module_type, user_email
      result_flag = "failure"
      @fields ||= {}
      begin
        data = client.retrieve_multiple(module_type, [["emailaddress1", "Equal", user_email]])
        unless data[:entities].blank?
          @fields["#{module_type}_fields"] = dynamics_module_data(client, module_type, user_email)
          result_flag = "success"
        end
      rescue => e
        Rails.logger.debug "#{e}"
        result_flag = "failure"
      end
      result_flag
    end

    def render_settings
       render :template => "integrations/applications/dynamics_crm/dynamics_settings",
              :locals => {:configs => params["configs"]},
              :layout => 'application' and return
    end

    def render_fields
      render :template => "integrations/applications/dynamics_crm/dynamics_fields",
             :layout => 'application' and return
    end

    def api_error
      {"error" => "#{t(:'integrations.dynamicscrm.form.api_error')}"} 
    end

end