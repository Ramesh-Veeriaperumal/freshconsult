require_relative '../../../test_helper'
require 'minitest/spec'

# Test cases for data store
class DataStoreTest < ActionController::TestCase
  def setup
    @tenant_id = 78_899
  end

  def test_singleton
    store_obj_1 = Search::V2::Store::Data.instance
    store_obj_2 = Search::V2::Store::Data.instance

    assert_equal store_obj_1, store_obj_2
  end

  # Test if config is stored in data store
  def test_config_add
    Search::V2::Store::Data.instance.store_config(@tenant_id)

    refute_nil Search::V2::Store::Data.instance.tenant_info(@tenant_id)
  end

  # Test if config is removed from data store
  def test_config_remove
    Search::V2::Store::Data.instance.remove_config(@tenant_id)

    assert_nil Search::V2::Store::Data.instance.tenant_info(@tenant_id)
  end
end
