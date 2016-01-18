class Integrations::CloudElementsController < ApplicationController

  skip_before_filter :check_privilege, :verify_authenticity_token
  before_filter :build_installed_app, :only => [:oauth_url]

  def oauth_url
    metadata = @metadata.merge({:element => params[:state]})
    response = service_obj({}, metadata).receive(:oauth_url)
    redirect_url = response['oauthUrl']
    redirect_to redirect_url
  end

  private

    def build_installed_app
      @installed_app = current_account.installed_applications.build(:application => app )
      @installed_app.configs = { :inputs => {} }
      @metadata = {:user_agent => request.user_agent}
    end

    def app
      Integrations::Application.find_by_name(Integrations::CloudElements::Crm::Constant::APP_NAMES[params[:state].to_sym])
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

    def instance_object_definition payload, metadata
      if metadata[:method] == 'post'
        service_obj(payload, metadata).receive(:create_instance_object_definition)
      else
        service_obj(payload, metadata).receive(:update_instance_object_definition)
      end
    end

    def instance_transformation payload, metadata 
      if metadata[:method] == 'post'
        service_obj(payload, metadata).receive(:create_instance_transformation)
      else
        service_obj(payload, metadata).receive(:update_instance_transformation)
      end
    end

    def create_formula_instance payload, metadata
      service_obj(payload, metadata).receive(:create_formula_instance)
    end

    def delete_formula_instance payload, metadata
      service_obj(payload, metadata).receive(:delete_formula_instance)
    end

end