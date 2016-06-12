module Integrations
  module ControllerMethods

    private

    def get_installed_app
      current_account.installed_applications.with_name(app_name).first
    end

    def load_installed_app
      @installed_app = get_installed_app
      unless @installed_app
        flash[:error] = t(:'flash.application.not_installed')
        redirect_to integrations_applications_path
      end
    end

    def check_installed_app
      if get_installed_app.present?
        flash[:notice] = t(:'flash.application.already') 
        redirect_to integrations_applications_path
      end 
    end

    def service_obj
      service_name = app_name.capitalize
      @service_obj ||= "IntegrationServices::Services::#{service_name}Service".constantize.new(@installed_app, {},:user_agent => request.user_agent)
    end

    # Override this method in controller
    def app_name
      raise NotImplementedError
    end 
  end
end