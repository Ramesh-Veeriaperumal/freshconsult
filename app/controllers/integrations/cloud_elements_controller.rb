class Integrations::CloudElementsController < ApplicationController

  private

  def build_installed_app
    @installed_app = current_account.installed_applications.find_by_application_id(app.id)
    if @installed_app.nil?
      @installed_app = current_account.installed_applications.build(:application => app )
      @installed_app.configs = { :inputs => {} }
    end
    @metadata = {:user_agent => request.user_agent, :app_name => element}
  end

  def load_installed_app
    @installed_app = current_account.installed_applications.find_by_application_id(app.id)
    @metadata = {:user_agent => request.user_agent, :app_name => element}
    unless @installed_app
      flash[:error] = t(:'flash.application.not_installed')
      redirect_to integrations_applications_path
    end
  end

  def app
    Integrations::Application.find_by_name(element)
  end

  def element
    # This is to facilitate params[:app_name] from the respective JS files
    params[:state].present? ? params[:state] : params[:app_name]
  end

  def service_obj payload, metadata
     @cloud_elements_obj = IntegrationServices::Services::CloudElementsService.new(@installed_app, payload, metadata)
  end

  def create_element_instance payload, metadata
    service_obj(payload, metadata).receive(:create_element_instance)
  end

  def check_element_instances
    #If element Instance Ids present then redirect to the edit route rather than the create routes.
    redirect_to "#{request.protocol}#{request.host_with_port}#{integrations_cloud_elements_crm_edit_path}?state=#{params[:state]}&method=put" and return if @installed_app.configs_element_instance_id.present?
  end

  def instance_object_definition payload, metadata
    if metadata[:method] == 'post' || !metadata[:update_action]
      service_obj(payload, metadata).receive(:create_instance_object_definition)
    else
      service_obj(payload, metadata).receive(:update_instance_object_definition)
    end
  end

  def instance_transformation payload, metadata 
    if metadata[:method] == 'post' || !metadata[:update_action]
      service_obj(payload, metadata).receive(:create_instance_transformation)
    else
      service_obj(payload, metadata).receive(:update_instance_transformation)
    end
  end

  def get_element_configs instance_id
    metadata = @metadata.merge({:element_instance_id => instance_id})
    service_obj({},metadata).receive(:get_element_configuration)
  end

  def update_element_configs instance_id, payload
    metadata = @metadata.merge({:element_instance_id => instance_id, :config_id => payload['id']})
    service_obj(payload, metadata).receive(:update_element_configuration)
  end

  def create_formula_instance payload, metadata
    service_obj(payload, metadata).receive(:create_formula_instance)
  end

  def update_formula_instance payload, metadata
    service_obj(payload, metadata).receive(:update_formula_instance)
  end

  def verify_authenticity
    render :status => 401 if current_user.blank? || !current_user.agent?
  end

end
