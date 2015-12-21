module IntegrationServices::Services
  module Magento
    class MagentoCustomerResource < MagentoResource

      def find email_id
        rest_url = @service.server_url + "/api/rest/customers"
        response =  http_get rest_url, {"filter"=>{"0"=>{"attribute"=>"email", "eq"=>email_id}}}
        process_response(response, 200)
      end

    private
      def process_response(response, *success_codes)
        if success_codes.include?(response.status)
          response = parse(response.body)      
          customer_ids = {}
          index = 0
          response.each do |key, value| 
            customer_ids[index] = value["entity_id"]
            index += 1
          end if response.present?

          if customer_ids.present?
            return {:status => 'Customer Found', :customer_id => customer_ids, :errors => nil}
          end 
          {:status => 'Customer Not Found', :customer_id => nil, :errors => "Email is not registered on this shop."}
        elsif response.status.between?(400, 499)
          {:status => 'Customer Not Found', :customer_id => nil, :errors => "Token invalid. Reinstall application."}
        else
          {:status => 'Customer Not Found', :customer_id => nil, :errors => "Unknown error. Try after sometime."}
        end
      end
    end
  end
end