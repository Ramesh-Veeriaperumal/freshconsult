module IntegrationServices::Services
  class CloudElementsService < IntegrationServices::Service
 
    def self.title
      'cloud_elements'
    end
 
    def server_url
      "https://staging.cloud-elements.com"
    end

    def receive_oauth_url
      cloud_elements_resource.get_oauth_url(oauth_rest_url)      
    end

    def receive_create_instances
      element_resource.create_instance
    end

    def receive_contact_metadata
      contact_resource.get_fields(@meta_data[:object])
    end

    def receive_account_metadata
      account_resource.get_fields(@meta_data[:object])
    end

    private

      def cloud_elements_resource
        @cloud_elements_resource ||= IntegrationServices::Services::CloudElements::CloudElementsResource.new(self)
      end

      def element_resource
        @element_resource ||= IntegrationServices::Services::CloudElements::ElementResource.new(self)
      end

      def contact_resource
        @contact_resource ||= IntegrationServices::Services::CloudElements::ObjectResources::ContactResource.new(self)
      end

      def account_resource
        @account_resource = IntegrationServices::Services::CloudElements::ObjectResources::AccountResource.new(self)
      end

      def transformation_resource
        @transformation_resource ||= IntegrationServices::Services::CloudElements::TransformationResource.new(self)
      end

      def formula_resource
        @formula_resource ||= IntegrationServices::Services::CloudElements::FormulaResource.new(self)
      end
       
      def oauth_rest_url
        "elements/#{@meta_data[:element]}/oauth/url"
      end

  end
end 
