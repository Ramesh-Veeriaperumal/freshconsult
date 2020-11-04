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
    UserSession.any_instance.stubs(:cookie_credentials).returns([sample_user.user.persistence_token, sample_user.user.id])
    @headers.except!('HTTP_AUTHORIZATION')
    return if @@before_all
    @@before_all = true
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

  def test_private_api_basic_auth
    auth = ActionController::HttpAuthentication::Basic.encode_credentials(@agent.email, 'test')
    get 'api/_/bootstrap', nil, @headers.merge('HTTP_AUTHORIZATION' => auth)
    assert_response 403
    response.body.must_match_json_expression(request_error_pattern('access_denied'))
  end

  def test_private_api_jwt_auth_with_ip_blocked
    @account.launch(:api_jwt_auth)
    token = generate_jwt_token(1, 1, Time.now.to_i, Time.now.to_i)
    auth = ActionController::HttpAuthentication::Token.encode_credentials(token)
    @account.features.whitelisted_ips.create
    create_whitelisted_ips
    @account.reload
    WhitelistedIp.any_instance.stubs(:ip_ranges).returns([{ start_ip: '172.0.1.1', end_ip: '172.0.1.10' }])
    @headers['CLIENT_IP'] = '0.0.0.0'
    get 'api/_/bootstrap', nil, @headers.merge('HTTP_AUTHORIZATION' => auth)
    assert_response 403
  ensure
    @account.features.whitelisted_ips.destroy
    WhitelistedIp.any_instance.unstub(:ip_ranges)
  end

  def test_private_api_basic_auth_ip_whitelisted
    @account.features.whitelisted_ips.create
    create_whitelisted_ips(true)
    @account.reload
    ip_ranges = @account.whitelisted_ip.ip_ranges.first.symbolize_keys!
    WhitelistedIp.any_instance.stubs(:ip_ranges).returns([ip_ranges])
    @headers['CLIENT_IP'] = '127.0.1.2'
    @account.launch(:api_jwt_auth)
    token = generate_jwt_token(1, 1, Time.now.to_i, Time.now.to_i)
    auth = ActionController::HttpAuthentication::Token.encode_credentials(token)
    get 'api/_/bootstrap', nil, @headers.merge('HTTP_AUTHORIZATION' => auth)
    assert_response 200
  ensure
    @account.features.whitelisted_ips.destroy
    WhitelistedIp.any_instance.unstub(:ip_ranges)
  end

  def test_private_api_jwt_auth
    @account.launch(:api_jwt_auth)
    token = generate_jwt_token(1, 1, Time.now.to_i, Time.now.to_i)
    auth = ActionController::HttpAuthentication::Token.encode_credentials(token)
    get 'api/_/bootstrap', nil, @headers.merge('HTTP_AUTHORIZATION' => auth)
    assert_response 200
  end

  def test_account_version_header
    requests, redis_timestamp, version_set = private_api_keys_values
    set_others_redis_hash(version_redis_key, version_set)
    acc_version = Digest::MD5.hexdigest(version_set.values.join)
    set_key(account_api_limit_key, '100', 1.minute)

    requests.each do |url|
      get url
      assert_equal acc_version, response.headers['X-Account-Data-Version']
    end
    remove_key(account_api_limit_key)
  end

  def test_account_version_header_after_launch_party_change
    disable_custom_translation do
      requests, redis_timestamp, version_set = private_api_keys_values
      set_others_redis_hash(version_redis_key, version_set)
      old_acc_version = Digest::MD5.hexdigest(version_set.values.join)
      @account.launch(:test_feature)
      data_version_after_launch = get_others_redis_hash(version_redis_key)
      data_version_after_launch.each_pair do |key, value|
        if key.starts_with?('TICKET_FIELD_LIST:TRANSLATION')
          del_other_redis_hash_value(version_redis_key, *key)
          data_version_after_launch.delete key
        end
      end
      new_acc_version = Digest::MD5.hexdigest(data_version_after_launch.values.compact.join)
      get requests.first
      data_version_after_controller_hit = get_others_redis_hash(version_redis_key)
      assert_not_equal old_acc_version, response.headers['X-Account-Data-Version']
      assert_equal new_acc_version, response.headers['X-Account-Data-Version'],
                   msg: "Expected #{new_acc_version} but actual #{response.headers['X-Account-Data-Version']},"\
                      "Data Versioning before => #{data_version_after_launch.inspect},"\
                      "after => #{data_version_after_controller_hit.inspect}"
    end
  end

  def test_account_version_header_custom_tranlsation_with_user_supported_language
    requests, redis_timestamp, version_set = private_api_keys_values
    account_support_language = user_language = 'fr'
    stub_custom_translation([account_support_language], user_language) do
      translation_version_key = format(CustomTranslation::VERSION_MEMBER_KEYS['Helpdesk::TicketField'], language_code: account_support_language)
      version_set[translation_version_key] = redis_timestamp
      set_others_redis_hash(version_redis_key, version_set)
      acc_version = Digest::MD5.hexdigest(version_set.values.join)
      set_key(account_api_limit_key, '100', 1.minute)

      requests.each do |url|
        get url
        assert_equal acc_version, response.headers['X-Account-Data-Version']
      end
      remove_key(account_api_limit_key)
    end
  end

  def test_account_version_header_custom_tranlsation_without_user_supported_language
    requests, redis_timestamp, version_set = private_api_keys_values
    account_support_language = 'fr'
    user_language = 'da'
    stub_custom_translation([account_support_language], user_language) do
      translation_version_key = format(CustomTranslation::VERSION_MEMBER_KEYS['Helpdesk::TicketField'], language_code: account_support_language)
      version_set[translation_version_key] = redis_timestamp
      set_others_redis_hash(version_redis_key, version_set)
      acc_version = Digest::MD5.hexdigest(version_set.except(translation_version_key).values.join)
      set_key(account_api_limit_key, '100', 1.minute)

      requests.each do |url|
        get url
        assert_equal acc_version, response.headers['X-Account-Data-Version']
      end
      remove_key(account_api_limit_key)
    end
  end

  def test_private_api_with_proper_app_jwt_auth
    token = generate_app_jwt_token(fc_account.product_account_id, Time.now.to_i, Time.now.to_i, 'freshconnect')
    auth = ['JWTAuth token=', token].join(' ')
    get "api/_/tickets/#{ticket.display_id}", nil, @headers.merge('X-App-Header' => auth)
    assert_response 200
    @account.freshconnect_account.destroy if @account.freshconnect_account.present?
  end

  def test_private_api_without_jwt_auth
    get "api/_/tickets/#{ticket.display_id}", nil, @headers.merge('X-App-Header' => 'nil')
    assert_response 401
    assert_equal request_error_pattern(:invalid_credentials).to_json, response.body
    @account.freshconnect_account.destroy if @account.freshconnect_account.present?
  end

  def test_private_api_app_auth_with_incorrect_app_name
    token = generate_app_jwt_token(fc_account.product_account_id, Time.now.to_i, Time.now.to_i, 'abc')
    auth = ['JWTAuth token=', token].join(' ')
    get "api/_/tickets/#{ticket.display_id}", nil, @headers.merge('X-App-Header' => auth)
    assert_response 401
    assert_equal request_error_pattern(:invalid_credentials).to_json, response.body
    @account.freshconnect_account.destroy if @account.freshconnect_account.present?
  end

  def test_private_api_app_auth_with_incorrect_product_acc_id
    token = generate_app_jwt_token('test', Time.now.to_i, Time.now.to_i, 'freshconnect')
    auth = ['JWTAuth token=', token].join(' ')
    get "api/_/tickets/#{ticket.display_id}", nil, @headers.merge('X-App-Header' => auth)
    assert_response 401
    assert_equal request_error_pattern(:invalid_credentials).to_json, response.body
    @account.freshconnect_account.destroy if @account.freshconnect_account.present?
  end

  def test_private_api_app_auth_with_expired_token
    token = generate_app_jwt_token(fc_account.product_account_id, Time.now.to_i, Time.now.to_i - 100, 'freshconnect')
    auth = ['JWTAuth token=', token].join(' ')
    get "api/_/tickets/#{ticket.display_id}", nil, @headers.merge('X-App-Header' => auth)
    assert_response 401
    assert_equal request_error_pattern(:invalid_credentials).to_json, response.body
    @account.freshconnect_account.destroy if @account.freshconnect_account.present?
  end

  def test_invalid_ticket_id_for_vault_token_generation
    id = '1abc'
    get "api/_/tickets/#{id}/vault_token"
    assert_response 404
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

  def ticket
    Helpdesk::Ticket.last || create_ticket(ticket_params_hash)
  end

  def fc_account
    create_freshconnect_account
  end

  def create_freshconnect_account
    product_account_id = Random.rand(11).to_s
    domain = [Faker::Lorem.characters(10), 'freshconnect', 'com'].join('.')
    acc = Freshconnect::Account.new(account_id: @account.id,
                                    product_account_id: product_account_id,
                                    enabled: true,
                                    freshconnect_domain: domain)
    acc.save!
    acc
  end

  def stub_custom_translation(acc_supported_lang, usr_lang)
    Account.any_instance.stubs(:custom_translations_enabled?).returns(true)
    Account.any_instance.stubs(:supported_language).returns(acc_supported_lang) if acc_supported_lang.present?
    User.any_instance.stubs(:supported_language).returns(usr_lang) if usr_lang.present?
    yield
    User.any_instance.stubs(:supported_language)
    Account.any_instance.unstub(:supported_language)
    Account.any_instance.unstub(:custom_translation_enabled?)
  end

  def disable_custom_translation
    Account.any_instance.stubs(:custom_translations_enabled?).returns(false)
    yield
    Account.any_instance.unstub(:custom_translation_enabled?)
  end

  def private_api_keys_values
    requests = ['/api/_/bootstrap', '/api/_/tickets', 'api/_/ticket_fields']
    redis_timestamp = 1.day.ago.to_i
    version_set = {
      'TICKET_FIELD_LIST' => redis_timestamp,
      'CONTACT_FIELD_LIST' => redis_timestamp,
      'COMPANY_FIELD_LIST' => redis_timestamp,
      'SURVEY_LIST' => redis_timestamp,
      'MARKETPLACE_APPS_LIST' => redis_timestamp,
      'AGENTS_GROUPS_LIST' => redis_timestamp,
      'FRESHCHAT_ACCOUNT_LIST' => redis_timestamp
    }
    [requests, redis_timestamp, version_set]
  end
end
