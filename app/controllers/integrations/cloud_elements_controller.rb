class Integrations::CloudElementsController < ApplicationController
  skip_before_filter :check_privilege, :verify_authenticity_token
  before_filter :verify_authenticity, :build_installed_app, :only => [:oauth_url]

  def oauth_url
    # unless current_account.features?(:cloud_elements_crm_sync)
    #   element = Integrations::CloudElements::Constant::APP_NAMES[params[:state].to_sym]
    #   redirect_to "/auth/#{element}?origin=id=#{current_account.id}"
    # else
    metadata = @metadata.merge({:element => params[:state]})
    response = service_obj({}, metadata).receive(:oauth_url)
    redirect_url = response['oauthUrl']
    redirect_to redirect_url
    # end
    rescue => e
      NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in installing the application : #{e.message}"}})
      flash[:error] = t(:'flash.application.install.error')
      redirect_to integrations_applications_path
  end

  def settings

    #where the endpoints applications/{id} will hit by setting install_action in the applications controller
    #redirect_to installed_applications/install if there is no feature
    #or redirect to the respective controller action inside cloud elements.
  end



  private

    def build_installed_app
      case element
      when "dynamicscrm"
        @installed_app = current_account.installed_applications.with_name(element).first
      else
        @installed_app = current_account.installed_applications.build(:application => app )
        @installed_app.configs = { :inputs => {} }
      end
      @metadata = {:user_agent => request.user_agent}
    end

    def app
      Integrations::Application.find_by_name(element)
    end

    def element
      Integrations::CloudElements::Crm::Constant::APP_NAMES[params[:state].to_sym]
    end

    def service_obj payload, metadata
       @cloud_elements_obj = IntegrationServices::Services::CloudElementsService.new(@installed_app, payload, metadata)
    end

    def create_element_instance payload, metadata
      service_obj(payload, metadata).receive(:create_element_instance)
    end

    def self.delete_element_instance installed_app, payload, metadata
      service_obj = IntegrationServices::Services::CloudElementsService.new( installed_app, payload, metadata)
      service_obj.receive(:delete_element_instance)
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

    def update_formula_instance payload, metadata
      service_obj(payload, metadata).receive(:update_formula_instance)
    end

    def self.delete_formula_instance installed_app, payload, metadata
      service_obj = IntegrationServices::Services::CloudElementsService.new( installed_app, payload, metadata)
      service_obj.receive(:delete_formula_instance)
    end

    def verify_authenticity
      render :status => 401 if current_user.blank? || !current_user.agent?
    end

end
