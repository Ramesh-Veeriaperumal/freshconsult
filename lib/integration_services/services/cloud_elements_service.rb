module IntegrationServices::Services
  class CloudElementsService < IntegrationServices::Service
 
    def self.title
      'cloud_elements'
    end
 
    def server_url 
      (["development", "staging"].include? Rails.env) ? "https://staging.cloud-elements.com" : "https://api.cloud-elements.com"
    end

    def receive_create_element_instance
      element_instance_resource.create_instance
    end

    def receive_delete_element_instance
      element_instance_resource.delete_instance
    end

    def receive_contact_metadata
      contact_resource.get_fields
    end

    def receive_account_metadata
      account_resource.get_fields
    end

    def receive_create_instance_object_definition
      object_resource.create_instance_level_object_definition
    end

    def receive_update_instance_object_definition
      object_resource.update_instance_level_object_definition
    end

    def receive_create_instance_transformation
      transformation_resource.create_instance_level_transformation
    end

    def receive_update_instance_transformation
      transformation_resource.update_instance_level_transformation
    end

    def receive_create_formula_instance
      formula_resource.create_instance
    end

    def receive_update_formula_instance
      formula_resource.update_instance
    end

    def receive_delete_formula_instance
      formula_resource.delete_instance
    end

    def receive_uninstall
      formula_instance_id = installed_app.configs_crm_to_helpdesk_formula_instance
      app_name = installed_app.application.name
      formula_id = Integrations::CRM_TO_HELPDESK_FORMULA_ID[app_name]
      Rails.logger.debug "Queing Instance Ids on uninstalling. Formula Template ID: #{formula_id}, Formula Instance Id: #{formula_instance_id}, 
        #{app_name} Instance Id: #{installed_app.configs_element_instance_id}, Freshdesk Instance Id: #{installed_app.configs_fd_instance_id}"
      metadata = {:user_agent => user_agent}
      formula_obj = self.class.new(installed_app, {}, metadata.merge({:formula_id => formula_id, :formula_instance_id => formula_instance_id}))
      formula_obj.receive(:delete_formula_instance)
      Rails.logger.debug "Deleting Formula Instance is Successfull."
      [installed_app.configs_element_instance_id, installed_app.configs_fd_instance_id].each do |element_id|
        options = {:element_id => element_id, :app_id => installed_app.application_id}
        Integrations::CloudElementsDeleteWorker.perform_async(options)     
      end 
      Rails.logger.debug "Queing Done Successfully."
      rescue Exception => e
        error_log = "Account: #{Account.current.full_domain}, Id: #{Account.current.id}, #{app_name}: Error on Formula Instance delete. Formula Template ID: #{formula_id}, Formula Instance Id: #{formula_instance_id}, 
          #{app_name} Instance Id: #{installed_app.configs_element_instance_id}, Freshdesk Instance Id: #{installed_app.configs_fd_instance_id}. Delete them Manually."
        FreshdeskErrorsMailer.error_email(nil, nil, e, {
          :subject => error_log, :recipients => "integration@freshdesk.com"
        })
    end

    private

      def cloud_elements_resource
        @cloud_elements_resource ||= IntegrationServices::Services::CloudElements::CloudElementsResource.new(self)
      end

      def element_instance_resource
        @element_instance_resource ||= IntegrationServices::Services::CloudElements::Platform::ElementInstanceResource.new(self)
      end

      def object_resource
        @object_resource ||= IntegrationServices::Services::CloudElements::Platform::ObjectResource.new(self)
      end

      def transformation_resource
        @transformation_resource ||= IntegrationServices::Services::CloudElements::Platform::TransformationResource.new(self)
      end

      def formula_resource
        @formula_resource ||= IntegrationServices::Services::CloudElements::Platform::FormulaResource.new(self)
      end

      def contact_resource
        @contact_resource ||= IntegrationServices::Services::CloudElements::Hub::Crm::ContactResource.new(self)
      end

      def account_resource
        @account_resource ||= IntegrationServices::Services::CloudElements::Hub::Crm::AccountResource.new(self)
      end

  end
end 
