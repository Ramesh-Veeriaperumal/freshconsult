require 'test_helper'
require 'minitest/spec'

# Test cases for cache store
class CacheStoreTest < ActionController::TestCase
  def setup
    @tenant_id = 78_899
  end

  def test_singleton
    store_obj_1 = Store::Cache.instance
    store_obj_2 = Store::Cache.instance

    assert_equal store_obj_1, store_obj_2
  end

  # Test if cluster key is added
  def test_cluster_key_add
    Store::Cache.instance.fetch(Store::Cache::CLUSTER % { tenant_id: @tenant_id }) do
      'http://localhost:9200'
    end

    refute_nil $memcache.fetch(Store::Cache::CLUSTER % { tenant_id: @tenant_id })
  end

  # Test if cluster key is removed
  def test_cluster_key_remove
    Store::Cache.instance.remove(Store::Cache::CLUSTER % { tenant_id: @tenant_id })

    assert_nil $memcache.fetch(Store::Cache::CLUSTER % { tenant_id: @tenant_id })
  end

  # Test if tenant key is added
  def test_tenant_key_add
    tenant = Store::Cache.instance.fetch(Store::Cache::TENANT % { tenant_id: @tenant_id }) do
      Tenant.new(@tenant_id)
    end

    assert_instance_of Tenant, tenant
    refute_nil $memcache.fetch(Store::Cache::TENANT % { tenant_id: @tenant_id })
  end

  # Test if tenant key is removed
  def test_tenant_key_remove
    Store::Cache.instance.remove(Store::Cache::TENANT % { tenant_id: @tenant_id })

    assert_nil $memcache.fetch(Store::Cache::TENANT % { tenant_id: @tenant_id })
  end

  # Test if tenant_info key is added
  def test_tenant_info_key_add
    Store::Cache.instance.fetch(Store::Cache::TENANT_INFO % { tenant_id: @tenant_id }) do
      { 'tenant_id' => @tenant_id, 'home_cluster' => 'http://localhost:9200' }
    end

    refute_nil $memcache.fetch(Store::Cache::TENANT_INFO % { tenant_id: @tenant_id })
  end

  # Test if tenant_info key is removed
  def test_tenant_info_key_remove
    Store::Cache.instance.remove(Store::Cache::TENANT_INFO % { tenant_id: @tenant_id })

    assert_nil $memcache.fetch(Store::Cache::TENANT_INFO % { tenant_id: @tenant_id })
  end

  # Test if alias key is added
  def test_alias_key_add
    Store::Cache.instance.fetch(Store::Cache::ALIAS % { tenant_id: @tenant_id, type: SUPPORTED_TYPES.first }) do
      "#{SUPPORTED_TYPES.first}_#{@tenant_id}"
    end

    refute_nil $memcache.fetch(Store::Cache::ALIAS % { tenant_id: @tenant_id, type: SUPPORTED_TYPES.first })
  end

  # Test if alias key is removed
  def test_alias_key_remove
    Store::Cache.instance.remove(Store::Cache::ALIAS % { tenant_id: @tenant_id, type: SUPPORTED_TYPES.first })

    assert_nil $memcache.fetch(Store::Cache::ALIAS % { tenant_id: @tenant_id, type: SUPPORTED_TYPES.first })
  end
end
