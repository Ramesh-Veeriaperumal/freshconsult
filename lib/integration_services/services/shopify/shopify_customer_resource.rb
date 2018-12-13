module IntegrationServices::Services
  module Shopify
    class ShopifyCustomerResource < IntegrationServices::Services::Shopify::ShopifyGenericResource
      
      def get_customer_id(email)
        return {} if email.blank?
        
        request_url = "#{server_url}/admin/customers/search.json?query=email:#{email}&fields=email,id"
        response = http_get request_url
        process_response(response, 200) do |customers|
          if customers['customers'] && customers['customers'][0] && customers['customers'][0]['id'] && customers['customers'][0]['email'].downcase! == email.downcase!
            return customers['customers'][0]['id']
          else
            return nil
          end
        end
      end
    end
  end
end