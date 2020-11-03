require_relative '../../test_helper'

class MarketplaceAppsFlowsTest < ActionDispatch::IntegrationTest
  include Redis::RedisKeys
  include Redis::OthersRedis
  include MarketplaceTestHelper

  CURRENT_VERSION = 'private-v1'.freeze

  @@before_all = false

  def setup
    CustomRequestStore.store[:private_api_request] ||= true
    super
    stub_marketplace_response
    before_all
  end

  def stub_marketplace_response
    Ember::MarketplaceAppsController.any_instance.stubs(:installed_extensions).returns(installed_extensions_v2)
    Ember::MarketplaceAppsController.any_instance.stubs(:extension_details_v2).returns(extension_details_v2)
  end

  def before_all
    return if @@before_all
    @@before_all = true
  end

  def test_index_without_timestamp
    get '/api/_/marketplace_apps', nil, @headers
    assert_response 200
  end

  def test_index_with_same_etag
    redis_timestamp = 1.day.ago.to_i
    $redis_others.hset(version_redis_key, 'MARKETPLACE_APPS_LIST', redis_timestamp)
    @write_headers = @headers.merge('If-None-Match' => EtagGenerator.generate_etag(redis_timestamp, CURRENT_VERSION))
    get '/api/_/marketplace_apps', nil, @write_headers
    assert_response 304
  end

  def test_index_with_different_etag
    $redis_others.hset(version_redis_key, 'MARKETPLACE_APPS_LIST', Time.zone.now.to_i)
    @write_headers = @headers.merge('If-None-Match' => EtagGenerator.generate_etag(1.hour.ago.to_i, CURRENT_VERSION))
    get '/api/_/marketplace_apps', nil, @write_headers
    assert_response 200
  end

  def test_index_without_updating_version_timestamp
    redis_timestamp = Time.zone.now.to_i
    $redis_others.hset(version_redis_key, 'MARKETPLACE_APPS_LIST', redis_timestamp)
    get '/api/_/marketplace_apps', nil, @headers.merge('If-None-Match' => EtagGenerator.generate_etag(1.hour.ago.to_i, CURRENT_VERSION))
    assert_response 200
    assert_not_equal get_others_redis_hash_value(version_redis_key, 'MARKETPLACE_APPS_LIST'), redis_timestamp
  end

  def version_redis_key
    format(DATA_VERSIONING_SET, account_id: @account.id)
  end
end
