module IntegrationServices::Services
  module Magento
    class MagentoOrdersResource < MagentoResource

      def get customer_ids
        rest_url = @service.server_url + "/api/rest/orders"
        params = {"filter"=>{"0"=>{"attribute"=>"customer_id", "in"=>customer_ids}}, "limit"=>"5", 
          "order"=>"entity_id", "dir"=>"dsc"}
        response =  http_get rest_url, params
        process_response(response, 200)
      end

    end
  end
end
