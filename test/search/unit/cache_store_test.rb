require_relative '../../test_helper'
require 'minitest/spec'

# Test cases for cache store
class CacheStoreTest < ActionController::TestCase
  def setup
    @tenant_id = 78_899

    # Start Memcache
    begin
      @pid = Process.spawn('memcached -vv')
      Process.detach(@pid)
      print("\n...Started memcached server ##{@pid}...".ansi(:cyan, :bold))
    rescue => e
      print('Could not start memcache server for test!!')
      exit(1)
    end
  end

  def teardown
    # Stop Memcache
    begin
      Process.kill('INT', @pid)
      print("\n...Stopped memcached server...".ansi(:cyan, :bold))
    rescue => e
      print('Could not stop memcache server after test!!')
      exit(1)
    end
  end

  def test_singleton
    store_obj_1 = Search::V2::Store::Cache.instance
    store_obj_2 = Search::V2::Store::Cache.instance

    assert_equal store_obj_1, store_obj_2
  end

  # Test if cluster key is added
  def test_cluster_key_add
    Search::V2::Store::Cache.instance.fetch(Search::V2::Store::Cache::CLUSTER % { tenant_id: @tenant_id }) do
      'http://localhost:9200'
    end

    refute_nil $memcache.fetch(Search::V2::Store::Cache::CLUSTER % { tenant_id: @tenant_id })
  end

  # Test if cluster key is removed
  def test_cluster_key_remove
    Search::V2::Store::Cache.instance.remove(Search::V2::Store::Cache::CLUSTER % { tenant_id: @tenant_id })

    assert_nil $memcache.fetch(Search::V2::Store::Cache::CLUSTER % { tenant_id: @tenant_id })
  end

  # Test if tenant key is added
  def test_tenant_key_add
    tenant = Search::V2::Store::Cache.instance.fetch(Search::V2::Store::Cache::TENANT % { tenant_id: @tenant_id }) do
      Search::V2::Tenant.new(@tenant_id)
    end

    assert_instance_of Search::V2::Tenant, tenant
    refute_nil $memcache.fetch(Search::V2::Store::Cache::TENANT % { tenant_id: @tenant_id })
  end

  # Test if tenant key is removed
  def test_tenant_key_remove
    Search::V2::Store::Cache.instance.remove(Search::V2::Store::Cache::TENANT % { tenant_id: @tenant_id })

    assert_nil $memcache.fetch(Search::V2::Store::Cache::TENANT % { tenant_id: @tenant_id })
  end

  # Test if tenant_info key is added
  def test_tenant_info_key_add
    Search::V2::Store::Cache.instance.fetch(Search::V2::Store::Cache::TENANT_INFO % { tenant_id: @tenant_id }) do
      { 'tenant_id' => @tenant_id, 'home_cluster' => 'http://localhost:9200' }
    end

    refute_nil $memcache.fetch(Search::V2::Store::Cache::TENANT_INFO % { tenant_id: @tenant_id })
  end

  # Test if tenant_info key is removed
  def test_tenant_info_key_remove
    Search::V2::Store::Cache.instance.remove(Search::V2::Store::Cache::TENANT_INFO % { tenant_id: @tenant_id })

    assert_nil $memcache.fetch(Search::V2::Store::Cache::TENANT_INFO % { tenant_id: @tenant_id })
  end

  # Test if alias key is added
  def test_alias_key_add
    Search::V2::Store::Cache.instance.fetch(Search::V2::Store::Cache::ALIAS % { tenant_id: @tenant_id, type: ES_V2_SUPPORTED_TYPES.first }) do
      "#{ES_V2_SUPPORTED_TYPES.first}_#{@tenant_id}"
    end

    refute_nil $memcache.fetch(Search::V2::Store::Cache::ALIAS % { tenant_id: @tenant_id, type: ES_V2_SUPPORTED_TYPES.first })
  end

  # Test if alias key is removed
  def test_alias_key_remove
    Search::V2::Store::Cache.instance.remove(Search::V2::Store::Cache::ALIAS % { tenant_id: @tenant_id, type: ES_V2_SUPPORTED_TYPES.first })

    assert_nil $memcache.fetch(Search::V2::Store::Cache::ALIAS % { tenant_id: @tenant_id, type: ES_V2_SUPPORTED_TYPES.first })
  end
end
