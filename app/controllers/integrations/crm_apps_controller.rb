class Integrations::CrmAppsController < ApplicationController
  include Integrations::Constants

  def settings
    render_settings             
  end

  def edit
    render_fields
  end

  def fields_update
    update_crm_fields and return
    redirect_to integrations_applications_path
  end


 private

  def get_installed_app
    @installed_app = current_account.installed_applications.with_name(get_app_name).first
  end

  def check_installed_app
    if get_installed_app.present?
      flash[:notice] = t(:'flash.application.already') 
      redirect_to integrations_applications_path
    end 
  end
  
  def render_cloud_elements
    if current_account.features?(:cloud_elements_crm_sync)
      get_installed_app
      if @installed_app.present? and @installed_app.configs[:inputs]["element_token"].present?
        redirect_to "/integrations/cloud_elements/crm/edit?state=dynamicscrm" and return
      else
        render_settings and return
      end
    end
  end

  def check_cloud_elements?
    get_installed_app
    if ["settings", "settings_update", "edit"].include? params["action"] and current_account.features?(:cloud_elements_crm_sync)
      if @installed_app.present? and @installed_app.configs[:inputs]["element_token"].blank?
        @installed_app = nil
        return false
      end
    end
    return true
  end

  def get_app_name
    params[:controller].split('/')[1]
  end

  def config_hash
    {}
  end

  def construct_app
    app = Integrations::Application.find_by_name(get_app_name)
    @installed_app = app.installed_applications.build
    @installed_app.account_id = current_account.id
    @installed_app.set_configs(config_hash)
  end

  def render_settings
    render :template => "integrations/applications/#{get_app_name}/#{get_app_name}_settings",
           :locals => {:configs => params["configs"]},
           :layout => 'application'
  end

  def render_fields
    render :template => "integrations/applications/form/crm_custom_fields_form",
           :layout => 'application' 
  end

  def update_crm_fields
    CRM_MODULE_TYPES.each do |m_type|
      label_key = "#{m_type}_labels"
      field_key = "#{m_type}s"
      @installed_app["configs"][:inputs][label_key] = params[label_key] if params[label_key].present?
      @installed_app["configs"][:inputs][field_key] = params[field_key] if params[field_key].present?
      if get_app_name != APP_NAMES[:dynamicscrm]
        @installed_app["configs"][:inputs][field_key]= @installed_app["configs"][:inputs][field_key].join(",") if params[field_key].present?
      end  
    end
    if @installed_app.save
      return if current_account.features?(:cloud_elements_crm_sync)
      flash[:notice] = t(:'flash.application.install.success') and return false
    else
      flash[:notice] = t(:'flash.application.install.failure') 
      redirect_to integrations_applications_path and return true
    end
  end

  def get_default_fields_params
    labels = @installed_app.application.options[:default_fields]
    label_to_field = { :accounts =>[], :contacts => [], :leads => [] }
    CRM_MODULE_TYPES.each do |type|
      labels[type.to_sym].each do |label|
        if @fields["#{type}_fields"].present? && @fields["#{type}_fields"][label]
          label_to_field["#{type}s".to_sym].push(@fields["#{type}_fields"][label])
        end
      end
      params["#{type}_labels"] = labels["#{type}".to_sym].join(",") if label_to_field["#{type}s".to_sym].present?
    end
     params.merge!(label_to_field)
  end

  # def build_params_for_cloud_elements
  #   inputs = @installed_app.configs[:inputs]
  #   label_to_field = { :accounts =>[], :contacts => [], :leads => [] }
  #   CRM_MODULE_TYPES.each do |type|
  #     if inputs["#{type}s"].present?
  #       inputs["#{type}s"].each do  |label|
  #         label_to_field["#{type}s".to_sym].push(label)
  #       end
  #     end
  #     params["#{type}_labels"] = inputs["#{type}_labels"] if inputs["#{type}_labels"].present?
  #   end
  #   params.merge!(label_to_field)
  # end

end
