class Integrations::CloudElementsController < ApplicationController

  private

    def build_installed_app
      @installed_app = current_account.installed_applications.find_by_application_id(app.id)
      if @installed_app.nil?
        @installed_app = current_account.installed_applications.build(:application => app )
        @installed_app.configs = { :inputs => {} }
      end
      @metadata = {:user_agent => request.user_agent}
    end

    def app
      Integrations::Application.find_by_name(element)
    end

    def element
      Integrations::CloudElements::Constant::APP_NAMES[params[:state].to_sym]
    end

    def service_obj payload, metadata
       @cloud_elements_obj = IntegrationServices::Services::CloudElementsService.new(@installed_app, payload, metadata)
    end

    def create_element_instance payload, metadata
      service_obj(payload, metadata).receive(:create_element_instance)
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
