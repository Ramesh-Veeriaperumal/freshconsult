require 'test_helper'
require 'minitest/spec'

# Test cases for data store
class DataStoreTest < ActionController::TestCase
  def setup
    @tenant_id = 78_899
  end

  def test_singleton
    store_obj_1 = Store::Data.instance
    store_obj_2 = Store::Data.instance

    assert_equal store_obj_1, store_obj_2
  end

  # Test if config is stored in data store
  def test_config_add
    Store::Data.instance.store_config(@tenant_id)

    refute_nil $dynamo_client.get_item(table_name: 'tenant_info', key: { tenant_id: @tenant_id }).item
  end

  # Test if config is removed from data store
  def test_config_remove
    Store::Data.instance.remove_config(@tenant_id)

    assert_nil $dynamo_client.get_item(table_name: 'tenant_info', key: { tenant_id: @tenant_id }).item
  end
end
