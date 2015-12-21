module IntegrationServices::Services
  class MagentoService < IntegrationServices::Service

    def self.title
      'Magento'
    end

    def receive_customer_orders
      orders = {}
      @payload[:position] = @payload[:position].to_i
      position = @payload[:position]
      @payload[:domain] = @installed_app[:configs][:inputs]["shops"][position]["shop_url"]
      shop_name = @installed_app[:configs][:inputs]["shops"][position]["shop_name"]
      response = receive_customer_id(payload[:email])

      if response[:status] == "Customer Found"
        orders[shop_name] = receive_orders(response[:customer_id])
      else
        orders[shop_name] = {:status => 400, :message => response[:errors]}
      end       
      orders[shop_name]["domain"] = @payload[:domain] 
      orders
    end

    def receive_customer_id(email_id)
      customer_resource.find(email_id)
    end

    def receive_orders(customer_id)
      orders_resource.get(customer_id)
    end

    def server_url
      @server_url ||= self.configs["shops"][@payload[:position]]["shop_url"]
    end

    private

      def orders_resource
        @orders_resource = IntegrationServices::Services::Magento::MagentoOrdersResource.new(self)
      end

      def customer_resource
        @customer_resource = IntegrationServices::Services::Magento::MagentoCustomerResource.new(self)
      end
  end
end