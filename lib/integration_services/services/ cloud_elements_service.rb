module IntegrationServices::Services
  class CloudElementsService < IntegrationServices::Service

    def self.title
      'cloud_elements'
    end

    def server_url
      "https://api.cloud-elements.com"
    end
    
  end
end