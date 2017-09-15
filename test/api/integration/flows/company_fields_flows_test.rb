require_relative '../../test_helper'

class CompanyFieldsFlowsTest < ActionDispatch::IntegrationTest
  include Redis::RedisKeys
  include Redis::OthersRedis
  def sample_user
    @account.all_agents.first
  end

  @@before_all = false
  
  def setup
    super
    before_all
  end

  def before_all
    return if @@before_all
    @@before_all = true
    @account.launch(:falcon)
  end

  def test_index_without_timestamp
    get '/api/_/company_fields', nil, @headers
    assert_response 200
  end

  def test_index_with_same_etag
    redis_timestamp = 1.day.ago.to_i
    $redis_others.hset(version_redis_key, 'COMPANY_FIELD_LIST', redis_timestamp)
    @write_headers = @headers.merge('If-None-Match' => EtagGenerator.generate_etag(redis_timestamp))
    get '/api/_/company_fields', nil, @write_headers
    assert_response 304
  end

  def test_index_with_different_etag
    $redis_others.hset(version_redis_key, 'COMPANY_FIELD_LIST', Time.zone.now.to_i)
    @write_headers = @headers.merge('If-None-Match' => EtagGenerator.generate_etag(1.hour.ago.to_i))
    get '/api/_/company_fields', nil, @write_headers
    assert_response 200
  end

  def test_index_without_updating_version_timestamp
    redis_timestamp = Time.zone.now.to_i
    $redis_others.hset(version_redis_key, 'COMPANY_FIELD_LIST', redis_timestamp)
    @write_headers = @headers.merge('If-None-Match' => EtagGenerator.generate_etag(1.hour.ago.to_i))
    get '/api/_/company_fields', nil, @write_headers
    assert_response 200
    new_redis_value = get_others_redis_hash_value(version_redis_key, 'COMPANY_FIELD_LIST')
    assert_not_equal new_redis_value, redis_timestamp
  end

  def version_redis_key
    DATA_VERSIONING_SET % { account_id: @account.id }
  end
end
