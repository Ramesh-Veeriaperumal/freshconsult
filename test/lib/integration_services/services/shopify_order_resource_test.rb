require_relative '../../../test_helper'
require_relative '../../helpers/shopify_helper'

class ShopifyOrderResourceTest < ActionView::TestCase
  include ShopifyHelper

  def setup
    Account.stubs(:current).returns(Account.first)
    @store = { shop_name: 'awesomedestroyed.myshopify.com' }
    @token = 'jaksdgeioankdjnkdsafnvndslkfsk'
    @customers = { customers: [{ id: 1, email: 'test@gmail.com' }.stringify_keys] }.stringify_keys
  end

  def teardown
    super
    Account.unstub(:current)
  end

  def test_get_recent_orders
    IntegrationServices::Services::Shopify::ShopifyOrderResource.any_instance.stubs(:http_get).returns(orders)
    IntegrationServices::Services::Shopify::ShopifyOrderResource.any_instance.stubs(:process_response).with(orders, 200).returns(orders)
    order_response = IntegrationServices::Services::Shopify::ShopifyOrderResource.new('IntegrationServices::Services::ShopifyService'.constantize.new(nil), @store, @token)
    recent_orders = order_response.get_recent_orders(@customers['customers'][0]['id'])
    assert recent_orders[:orders][0].key?(:name)
  end

  def test_validate_order
    IntegrationServices::Services::Shopify::ShopifyOrderResource.any_instance.stubs(:http_get).returns(orders)
    IntegrationServices::Services::Shopify::ShopifyOrderResource.any_instance.stubs(:process_response).with(orders, 200).returns(orders)
    order_response = IntegrationServices::Services::Shopify::ShopifyOrderResource.new('IntegrationServices::Services::ShopifyService'.constantize.new(nil), @store, @token)
    recent_orders = order_response.get_recent_orders(@customers['customers'][0]['id'])
    assert recent_orders[:orders][0].key?(:name)
  end

  def test_format_order
    IntegrationServices::Services::Shopify::ShopifyOrderResource.any_instance.stubs(:http_get).returns(orders)
    IntegrationServices::Services::Shopify::ShopifyOrderResource.any_instance.stubs(:process_response).with(orders, 200).returns(orders)
    order_response = IntegrationServices::Services::Shopify::ShopifyOrderResource.new('IntegrationServices::Services::ShopifyService'.constantize.new(nil), @store, @token)
    recent_orders = order_response.get_recent_orders(@customers['customers'][0]['id'])
    formatted_order = order_response.send(:format_order, recent_orders[:orders][0].stringify_keys)
    assert_equal(formatted_order['name'], '###FF##1019')
  end
end
