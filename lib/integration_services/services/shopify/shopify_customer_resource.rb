module IntegrationServices::Services
  module Shopify
    class ShopifyCustomerResource < IntegrationServices::Services::Shopify::ShopifyGenericResource
      def get_customer_id(email, phone)
        if email.present?
          request_url = "#{server_url}/admin/#{SHOPIFY_API_VERSION}/customers/search.json?query=email:#{email}&fields=email,id"
        elsif phone.present?
          # removing any special characters other than digits
          phone.gsub!(/\D/, '')
          request_url = "#{server_url}/admin/#{SHOPIFY_API_VERSION}/customers/search.json?query=phone:#{phone}&fields=phone,id"
        else
          Rails.logger.info("No email or phone is present to fetch the shopify customer id.")
          return {}
        end
        response = http_get request_url
        process_response(response, 200) do |customers|
          if email.present? && customer_id(customers) && customer_email(customers).casecmp(email).zero?
            return customer_id(customers)
          elsif phone.present? && customer_id(customers)
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
