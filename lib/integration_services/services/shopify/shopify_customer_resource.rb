module IntegrationServices::Services
  module Shopify
    class ShopifyCustomerResource < IntegrationServices::Services::Shopify::ShopifyGenericResource
      
      def get_customer_id(email)
        return {} if email.blank?
        
        request_url = "#{server_url}/admin/customers/search.json?query=email:#{email}&fields=email,id"
        response = http_get request_url
        process_response(response, 200) do |customers|
          if customer_id(customers) && customer_email(customers).casecmp(email).zero?
            return customer_id(customers)
          else
            return nil
          end
        end
      end

      def customer_email(customers)
        customers.try(:[], 'customers').try(:first).try(:[], 'email')
      end

      def customer_id(customers)
        customers.try(:[], 'customers').try(:first).try(:[], 'id')
      end
    end
  end
end