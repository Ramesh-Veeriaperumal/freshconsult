require_relative '../../test_helper'

class PrivateApiFlowsTest < ActionDispatch::IntegrationTest

  include Redis::RedisKeys
  include Redis::OthersRedis

  def sample_user
    @account.all_agents.first
  end

  @@before_all = false

  def setup
    super

    UserSession.any_instance.stubs(:cookie_credentials).returns([sample_user.user.persistence_token, sample_user.user.id])
    @headers.except!('HTTP_AUTHORIZATION')

    before_all
  end

  def before_all
    return if @@before_all
    @@before_all = true
    @account.add_feature(:falcon)
  end

  def test_throttler_for_valid_request
    remove_key(account_api_limit_key)
    remove_key(private_api_key)
    set_key(account_api_limit_key, '10', 1.minute)
    old_consumed_limit = get_key(account_api_limit_key).to_i
    get '/api/_/bootstrap', nil, @headers
    new_consumed_limit = get_key(private_api_key).to_i
    assert_response 200
    assert_equal 1, new_consumed_limit
    remove_key(account_api_limit_key)
  end

  def test_throttler_for_multiple_requests
    arr = ['/api/_/bootstrap', '/api/_/tickets', 'api/_/ticket_fields']
    remove_key(account_api_limit_key)
    remove_key(private_api_key)
    set_key(account_api_limit_key, '10', 1.minute)
    5.times do |n|
      get arr.sample, @headers
    end
    new_consumed_limit = get_key(private_api_key).to_i
    assert_equal 5, new_consumed_limit
    remove_key(account_api_limit_key)
  end

  def test_throttler_for_non_existent_api
    remove_key(account_api_limit_key)
    remove_key(private_api_key)
    set_key(account_api_limit_key, '10', 1.minute)
    old_consumed_limit = get_key(private_api_key).to_i
    get '/api/_/admin/home', @headers
    new_consumed_limit = get_key(private_api_key).to_i
    assert_response 404
    assert_equal old_consumed_limit + 1, new_consumed_limit
    remove_key(account_api_limit_key)
  end

  def test_throttler_for_valid_request_with_extra_credits
    remove_key(account_api_limit_key)
    remove_key(private_api_key)
    set_key(account_api_limit_key, '10', 1.minute)
    Middleware::PrivateApiThrottler.any_instance.stubs(:extra_credits).returns(10)
    get '/api/_/bootstrap', nil, @headers
    new_consumed_limit = get_key(private_api_key).to_i
    assert_response 200
    assert_equal 11, new_consumed_limit
  ensure
    remove_key(account_api_limit_key)
    Middleware::FdApiThrottler.any_instance.unstub(:extra_credits)
  end

  def test_throttler_for_valid_request_but_limit_exceeded
    remove_key(private_api_key)
    set_key(private_api_key, '10', 1.minute)
    set_key(account_api_limit_key, '10', 1.minute)
    get '/api/_/bootstrap', nil, @headers
    assert_response 429
    remove_key(account_api_limit_key)
  end

  def test_shard_blocked_response
    ShardMapping.any_instance.stubs(:not_found?).returns(true)
    get '/api/_/bootstrap', nil, @headers
    assert_response 404
    assert_equal ' ', @response.body
    ShardMapping.any_instance.unstub(:not_found?)
  end

  def test_account_version_header
    requests = ['/api/_/bootstrap', '/api/_/tickets', 'api/_/ticket_fields']
    redis_timestamp = 1.day.ago.to_i
    version_set = {
      'TICKET_FIELD_LIST' => redis_timestamp,
      'CONTACT_FIELD_LIST' => redis_timestamp,
      'COMPANY_FIELD_LIST' => redis_timestamp,
      'SURVEY_LIST' => redis_timestamp
    }
    set_others_redis_hash(version_redis_key, version_set)
    acc_version = Digest::MD5.hexdigest(version_set.values.join)
    set_key(account_api_limit_key, '100', 1.minute)

    requests.each do |url|
      get url
      assert_equal acc_version, response.headers["X-Account-Data-Version"]
    end
    remove_key(account_api_limit_key)
  end

  def private_api_key(account_id = @account.id)
    "PRIVATE_API_THROTTLER:#{account_id}"
  end

  def account_api_limit_key(account_id = @account.id)
    "ACCOUNT_PRIVATE_API_LIMIT:#{account_id}"
  end

  def version_redis_key
    DATA_VERSIONING_SET % { account_id: @account.id }
  end
end
