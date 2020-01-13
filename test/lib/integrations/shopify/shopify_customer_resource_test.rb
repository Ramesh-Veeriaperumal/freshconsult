require_relative '../../test_helper'
require 'minitest/spec'
class ShopifyCustomerResource < ActiveSupport::TestCase
  def setup
    @store = { shop_name: 'shop_name: proactive-automation.myshopify.com' }
    @token = 'jaksdgeioankdjnkdsafnvndslkfsk'
  end

  def test_get_customer_id_valid
    c_res = IntegrationServices::Services::Shopify::ShopifyCustomerResource.new('IntegrationServices::Services::ShopifyService'.constantize.new(nil), @store, @token)
    customers = { 'customers': [{ 'id': 1, 'email': 'test@gmail.com', 'phone': '9999999999' }.stringify_keys] }.stringify_keys
    IntegrationServices::Services::Shopify::ShopifyCustomerResource.any_instance.stubs(:http_get).returns(customers)
    IntegrationServices::Services::Shopify::ShopifyCustomerResource.any_instance.stubs(:process_response).with(customers, 200).returns(customers['customers'][0]['id'])
    assert_equal c_res.get_customer_id('test@gamil.com', '9999999999'), customers['customers'][0]['id']
  ensure
    IntegrationServices::Services::Shopify::ShopifyCustomerResource.any_instance.unstub
  end

  def test_get_customer_id_from_phone_valid
    c_res = IntegrationServices::Services::Shopify::ShopifyCustomerResource.new('IntegrationServices::Services::ShopifyService'.constantize.new(nil), @store, @token)
    customers = { 'customers': [{ 'id': 1, 'email': nil, 'phone': '9999999999' }.stringify_keys] }.stringify_keys
    IntegrationServices::Services::Shopify::ShopifyCustomerResource.any_instance.stubs(:http_get).returns(customers)
    IntegrationServices::Services::Shopify::ShopifyCustomerResource.any_instance.stubs(:process_response).with(customers, 200).returns(customers['customers'][0]['id'])
    assert_equal c_res.get_customer_id(nil, '9999999999'), customers['customers'][0]['id']
  ensure
    IntegrationServices::Services::Shopify::ShopifyCustomerResource.any_instance.unstub
  end
end
