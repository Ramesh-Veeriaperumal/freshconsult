module IntegrationServices::Services
  class CloudElementsService < IntegrationServices::Service
 
    def self.title
      'cloud_elements'
    end
 
    def server_url
      "https://staging.cloud-elements.com"
    end

    def receive_oauth_url
      cloud_elements_resource.get_oauth_url      
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

    def receive_lead_metadata
      lead_resource.get_fields
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

    def receive_delete_formula_instance
      formula_resource.delete_instance
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

      def lead_resource
        @lead_resource ||= IntegrationServices::Services::CloudElements::Hub::Crm::LeadResource.new(self)
      end

  end
end 
