module IntegrationServices::Services
  class ShopifyService < IntegrationServices::Service

    def init
      stores
      @payload[:store] = nil if !@stores.any? { |store| store[:shop_name] == @payload[:store] }
      @current_store = @payload[:store] ? (@stores.select { |store| store[:shop_name] == @payload[:store] }).first : @current_store
      @token = token(@current_store)
    end

    def receive_fetch_orders
      init
      email = @payload[:email]
      phone = @payload[:phone]
      customer_id = get_customer_id(email, phone)
      recent_orders = get_recent_orders(customer_id)
      { 'orders' => recent_orders, 'stores' => @stores }
    end

    def receive_cancel_order
      raise_403 if shopify_action_disabled?
      init
      order_id = @payload[:orderId]
      cancel_order(order_id)
    end

    def receive_refund_full_order
      raise_403 if shopify_action_disabled?
      init
      order_id = @payload[:orderId]
      refund = refund_full_order(order_id)
    end

    def receive_refund_line_item
      raise_403 if shopify_action_disabled?
      init
      order_id = @payload[:orderId]
      line_item_id = @payload[:lineItemId]
      refund = refund_line_item(order_id, line_item_id)
    end

    private

      def get_customer_id(email, phone)
        customer_resource = IntegrationServices::Services::Shopify::ShopifyCustomerResource.new(self, @current_store, @token)
        customer_resource.get_customer_id(email, phone)
      end

      def get_recent_orders(customer_id)
        order_resource = IntegrationServices::Services::Shopify::ShopifyOrderResource.new(self, @current_store, @token)
        order_resource.get_recent_orders(customer_id)
      end

      def cancel_order(order_id)
        order_resource = IntegrationServices::Services::Shopify::ShopifyOrderResource.new(self, @current_store, @token)
        order_resource.cancel_order(order_id)
      end

      def refund_full_order(order_id)
        refund_resource = IntegrationServices::Services::Shopify::ShopifyRefundResource.new(self, @current_store, @token)
        refund_resource.refund_full_order(order_id)
      end

      def refund_line_item(order_id, line_item_id)
        refund_resource = IntegrationServices::Services::Shopify::ShopifyRefundResource.new(self, @current_store, @token)
        refund_resource.refund_line_item(order_id, line_item_id)
      end

      def stores
        @stores = []
        @stores << { shop_name: @installed_app.configs[:inputs]['shop_name'], shop_display_name: @installed_app.configs[:inputs]['shop_display_name'] || @installed_app.configs[:inputs]['shop_name'] }
        if @installed_app.configs[:inputs]['additional_stores']
          @installed_app.configs[:inputs]['additional_stores'].keys.each do |key|
            additional_store = @installed_app.configs[:inputs]['additional_stores'][key]
            @stores << { shop_name: key, shop_display_name: additional_store['shop_display_name'] || additional_store['shop_name'] }
          end
        end
        @current_store = @stores[0]
      end

      def token(store)
        shop_name = store[:shop_name]
        if @installed_app.configs[:inputs]['shop_name'] == shop_name
          return @installed_app.configs[:inputs]['oauth_token']
        end
        return @installed_app.configs[:inputs]['additional_stores'] && @installed_app.configs[:inputs]['additional_stores'][shop_name] && @installed_app.configs[:inputs]['additional_stores'][shop_name]['oauth_token']
      end

      def shopify_action_disabled?
        @installed_app.configs[:inputs]['disable_shopify_actions']
      end

      def raise_403
        raise AccessDeniedError, 'Account not enabled for this Action'
      end
  end
end
