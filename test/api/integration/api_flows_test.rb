require_relative '../test_helper'

class ApiFlowsTest < ActionDispatch::IntegrationTest
  include Helpers::DiscussionsTestHelper
  include Helpers::TicketFieldsTestHelper

  def test_json_format
    get '/api/discussions/categories.json', nil, @headers
    assert_response 200
    assert_equal Array, parse_response(@response.body).class
  end

  def test_no_format
    get '/api/discussions/categories', nil, @headers
    assert_response 200
    assert_equal Array, parse_response(@response.body).class
  end

  def test_non_json_format
    get '/api/discussions/categories.js', nil, @headers
    assert_response :missing
    assert_equal ' ', @response.body
  end

  def test_no_route
    put '/api/discussions/category', '{"name": "true"}', @write_headers
    assert_response :missing
    assert_equal ' ', @response.body
  end

  def test_invalid_account
    get '/api/discussions/categories', nil, @headers.merge('HTTP_HOST' => 'junkaccount.freshpo.com')
    assert_response 404
    assert_equal ' ', @response.body

    get '/api/discussions/categories', nil, @headers
    assert_response 200
  end

  def test_method_not_allowed
    post '/api/discussions/categories/1', '{"name": "true"}', @write_headers
    assert_response 405
    response.body.must_match_json_expression(base_error_pattern('method_not_allowed', methods: 'GET, PUT, DELETE'))
    assert_equal 'GET, PUT, DELETE', response.headers['Allow']
  end

  def test_invalid_json
    post '/api/discussions/categories', '{"category": {"name": "true"', @write_headers
    assert_response 400
    response.body.must_match_json_expression(invalid_json_error_pattern)
  end

  def test_domain_not_ready
    Sharding.stubs(:select_shard_of).raises(DomainNotReady)
    post '/api/discussions/categories', '{"name": "testdd"}', @write_headers
    assert_response :missing
    response.body.must_match_json_expression(message: String)
  end

  def test_trusted_ip_invalid
    @account.features.whitelisted_ips.create
    create_whitelisted_ips(true)
    @account.reload
    ip_ranges = @account.whitelisted_ip.ip_ranges.first.symbolize_keys!
    WhitelistedIp.any_instance.stubs(:ip_ranges).returns([ip_ranges])
    ApiDiscussions::CategoriesController.any_instance.expects(:create).never
    Middleware::TrustedIp.any_instance.expects(:trusted_ip_applicable_to_user).never
    post '/api/discussions/categories', '{"name": "testdd_truested_ip"}', @write_headers
    assert_nil ForumCategory.find_by_name('testdd_truested_ip')
    assert_response 403
    response.body.must_match_json_expression(message: String)
  ensure
    ApiDiscussions::CategoriesController.any_instance.unstub(:create)
    Middleware::TrustedIp.any_instance.unstub(:trusted_ip_applicable_to_user)
    @account.features.whitelisted_ips.destroy
  end

  def test_trusted_ip_invalid_shard
    ShardMapping.stubs(:lookup_with_domain).returns(nil)
    Middleware::TrustedIp.any_instance.expects(:trusted_ips_enabled).never
    post '/api/discussions/categories', { 'name' => 'testdd_truested_ip' }.to_json, @write_headers
    assert_response 404
  ensure
    ShardMapping.unstub(:lookup_with_domain)
  end

  def test_trusted_ip_invalid_subdomain
    Middleware::TrustedIp.any_instance.expects(:trusted_ips_enabled?).never
    ApiApplicationController.any_instance.expects(:route_not_found).once
    post '/api/discussions/categories', '{"name": "testdd_truested_ip"}', @write_headers.merge('HTTP_HOST' => 'billing.junk.com')
    assert_nil ForumCategory.find_by_name('testdd_truested_ip')
    assert_response 404
  ensure
    Middleware::TrustedIp.any_instance.unstub(:trusted_ips_enabled?)
    ApiApplicationController.any_instance.unstub(:route_not_found)
  end

  def test_trusted_ip_invalid_non_api
    Middleware::TrustedIp.any_instance.stubs(:trusted_ips_enabled?).returns(true)
    Middleware::TrustedIp.any_instance.stubs(:valid_ip).returns(false)
    DiscussionsController.any_instance.expects(:categories).once
    get '/discussions/categories', nil, @headers.merge('rack.session' => { 'user_credentials_id' => '22' })
    assert_response 302
    assert_equal '/unauthorized.html', response.headers['Location']
  ensure
    Middleware::TrustedIp.any_instance.unstub(:trusted_ips_enabled?)
    Middleware::TrustedIp.any_instance.unstub(:valid_ip)
    DiscussionsController.any_instance.unstub(:categories)
  end

  def test_globally_blacklisted_ip_invalid
    GlobalBlacklistedIp.any_instance.stubs(:ip_list).returns(['127.0.0.1'])
    post '/api/discussions/categories', '{"name": "testdd"}', @write_headers
    GlobalBlacklistedIp.any_instance.unstub(:ip_list)
    assert_response 403
    response.body.must_match_json_expression(message: String)
  end

  def test_unsupported_media_type_invalid_content_type
    post '/api/discussions/categories', '{"category": {"name": "true"}}', @headers.merge('CONTENT_TYPE' => 'text/plain')
    assert_response 415
    response.body.must_match_json_expression(un_supported_media_type_error_pattern)
  end

  def test_unsupported_media_type_invalid_content_type_with_no_body
    post '/api/discussions/categories', nil, @headers.merge('CONTENT_TYPE' => 'text/plain')
    assert_response 415
    response.body.must_match_json_expression(un_supported_media_type_error_pattern)
  end

  def test_multipart_valid_content_type
    skip_bullet do
      headers, params = encode_multipart({ 'email' => 'test@abc.com', 'subject' => 'Test Subject', 'description' => 'Test', 'priority' => '1', 'status' => '2' }, 'attachments[]', File.join(Rails.root, 'test/api/fixtures/files/image33kb.jpg'), 'image/jpg', true)
      post '/api/tickets', params, @headers.merge(headers)
    end
    assert_response 201
    assert_equal Hash, parse_response(@response.body).class
  end

  def test_multipart_invalid_data_parsable
    skip_bullet do
      params = { 'email' => Faker::Internet.email, 'subject' => 'Test Subject' }.to_json
      post '/api/tickets', params, @headers.merge('CONTENT_TYPE' => 'multipart/form-data')
    end
    assert_response :bad_request
    response.body.must_match_json_expression(request_error_pattern('invalid_multipart'))
  end

  def test_multipart_invalid_data_unparsable
    skip_bullet do
      headers, params = encode_multipart({ 'ticket' => { 'email' => 'test@abc.com', 'subject' => 'Test Subject' } }, 'attachments', File.join(Rails.root, 'test/api/fixtures/files/image33kb.jpg'), 'image/jpg', false)
      Rack::Utils.stubs(:parse_nested_query).raises(ArgumentError)
      post '/api/tickets', params, @headers.merge(headers)
    end
    assert_response :internal_server_error
  end

  def test_unsupported_media_type_without_content_type
    post '/api/discussions/categories', '{"category": {"name": "true"}}', @headers
    assert_response 415
    response.body.must_match_json_expression(un_supported_media_type_error_pattern)
  end

  def test_unsupported_media_type_get_request
    get '/api/discussions/categories', nil, @headers
    assert_response 200
    assert_equal Array, parse_response(@response.body).class
  end

  def test_record_not_unique_error
    error = ActiveRecord::RecordNotUnique.new('RecordNotUnique', 'Duplicate-Entry')
    error.set_backtrace(['a', 'b'])
    User.any_instance.stubs(:create_contact!).raises(error)
    skip_bullet do
      post '/api/contacts',  { 'email' => Faker::Internet.email, 'name' => 'Test Subject' }.to_json, @write_headers
    end
    assert_response 409
    response.body.must_match_json_expression(request_error_pattern('duplicate_value'))
  end

  def test_statement_invalid_error
    error = ActiveRecord::StatementInvalid.new
    error.set_backtrace(['a', 'b'])
    User.any_instance.stubs(:create_contact!).raises(error)
    skip_bullet do
      post '/api/contacts',  { 'email' => Faker::Internet.email, 'name' => 'Test Subject' }.to_json, @write_headers
    end
    assert_response 500
    response.body.must_match_json_expression(base_error_pattern(:internal_error))
  end

  def test_multipart_data_with_valid_data_types
    tkt_field1 = create_custom_field('test_custom_decimal', 'decimal')
    tkt_field2 = create_custom_field('test_custom_checkbox', 'checkbox')
    field1 = tkt_field1.name
    field2 = tkt_field2.name
    headers, params = encode_multipart({  'subject' => 'Test Subject', 'description' => 'Test', 'priority' => '1', 'status' => '2', 'requester_id' => "#{@agent.id}", 'custom_fields' => { "#{field1}" => '2.34', "#{field2}" => 'false' } }, 'attachments[]', File.join(Rails.root, 'test/api/fixtures/files/image33kb.jpg'), 'image/jpg', true)
    skip_bullet do
      post '/api/tickets', params, @headers.merge(headers)
    end
    [tkt_field1, tkt_field2].each(&:destroy)
    assert_response 201
    assert_equal Hash, parse_response(@response.body).class
    result = JSON.parse(@response.body)
    assert_equal @agent.id, result['requester_id']
    assert_equal '2.34', result['custom_fields']["#{field1}"]
    assert_equal false, result['custom_fields']["#{field2}"]
  end

  def test_not_acceptable_invalid_type
    get '/api/discussions/categories', nil, @headers.merge('HTTP_ACCEPT' => 'application/xml')
    assert_response 406
    response.body.must_match_json_expression(not_acceptable_error_pattern)
  end

  def test_not_acceptable_valid
    get '/api/discussions/categories', nil, @headers.merge('HTTP_ACCEPT' => '*/*')
    assert_response 200
  end

  def test_not_acceptable_valid_custom_header
    get '/api/discussions/categories', nil, @headers.merge('HTTP_ACCEPT' => 'application/vnd.freshdesk.v2')
    assert_response 200
  end

  def test_not_acceptable_valid_json_type
    get '/api/discussions/categories', nil,  @headers.merge('HTTP_ACCEPT' => 'application/json')
    assert_response 200
  end

  def test_not_valid_fd_domain
    without_proper_fd_domain do
      get '/api/discussions/categories', nil, headers
      assert_response :missing
    end
  end

  def test_not_valid_environment
    stub_const(ApiConstants, 'DEMOSITE_URL', @account.full_domain) do
      get '/api/discussions/categories', nil, headers
      assert_response :missing
    end
  end

  def test_account_suspended_json
    subscription = @account.subscription
    subscription.update_column(:state, 'suspended')
    post '/api/discussions/categories', nil, @write_headers
    response = parse_response(@response.body)
    assert_equal({ 'code' => 'account_suspended', 'message' => 'Your account has been suspended.' }, response)
    assert_response 403
    subscription.update_column(:state, 'trial')
  end

  def test_account_suspended_json_for_get_requests
    subscription = @account.subscription
    subscription.update_column(:state, 'suspended')
    get '/api/discussions/categories', nil, @headers
    response = parse_response(@response.body)
    assert_equal({ 'code' => 'account_suspended', 'message' => 'Your account has been suspended.' }, response)
    assert_response 403
    subscription.update_column(:state, 'trial')
  end

  def test_day_pass_expired_json
    Agent.any_instance.stubs(:occasional).returns(true).once
    subscription = @account.subscription
    subscription.update_column(:state, 'active')
    get '/agents.json', nil, @write_headers
    response = parse_response(@response.body)
    assert_equal({ 'code' => 'access_denied', 'message' => 'You are not authorized to perform this action.' }, response)
    assert_response 403
  end

  def test_authenticating_get_request
    ApiDiscussions::CategoriesController.any_instance.expects(:authenticate_with_http_basic).never
    get '/api/discussions/categories', nil, @headers
  end

  def test_authenticating_post_request_with_password
    ApiDiscussions::CategoriesController.expects(:current_user_session).never
    @write_headers = set_custom_auth_headers(@write_headers, @agent.reload.email, 'test')
    post '/api/discussions/categories', v2_category_payload, @write_headers
    assert_response 201
  end

  def test_authenticating_post_request_with_consecutive_invalid_pwd
    flc = @agent.failed_login_count || 0
    pt = @agent.perishable_token
    ApiDiscussions::CategoriesController.expects(:current_user_session).never
    @write_headers = set_custom_auth_headers(@write_headers, @agent.reload.email, 'tester')
    post '/api/discussions/categories', v2_category_payload, @write_headers
    assert_response 401
    assert_equal flc + 1, @agent.reload.failed_login_count
    assert pt != @agent.perishable_token

    post '/api/discussions/categories', v2_category_payload, @write_headers
    assert_response 401
    assert_equal flc + 2, @agent.reload.failed_login_count

    @write_headers = set_custom_auth_headers(@write_headers, @agent.email, 'test')
    post '/api/discussions/categories', v2_category_payload, @write_headers
    assert_response 201
    assert_equal 0, @agent.reload.failed_login_count
  end

  def test_authenticating_get_request_with_consecutive_invalid_pwd
    flc = @agent.failed_login_count || 0
    pt = @agent.perishable_token

    @headers = set_custom_auth_headers(@headers, @agent.reload.email, 'tes')
    get '/api/discussions/categories', nil, @headers
    assert_response 401
    assert_equal flc + 1, @agent.reload.failed_login_count
    assert pt != @agent.perishable_token

    get '/api/discussions/categories', nil, @headers
    assert_response 401
    assert_equal flc + 2, @agent.reload.failed_login_count

    @headers = set_custom_auth_headers(@headers, @agent.email, 'test')
    get '/api/discussions/categories', nil, @headers
    assert_response 200
    assert_equal 0, @agent.reload.failed_login_count
  end

  def test_authenticating_post_request_with_token
    ApiDiscussions::CategoriesController.expects(:current_user_session).never
    post '/api/discussions/categories', v2_category_payload, @write_headers
    assert_response 201
  end

  def test_authenticating_post_request_with_invalid_token
    ApiDiscussions::CategoriesController.expects(:current_user_session).never
    @write_headers = set_custom_auth_headers(@write_headers, 'test', 'X')
    post '/api/discussions/categories', v2_category_payload, @write_headers
    assert_response 401
  end

  def test_valid_authentication_invalid_user
    ApiDiscussions::CategoriesController.expects(:current_user_session).never
    @agent.update_column(:active, false)
    post '/api/discussions/categories', v2_category_payload, @write_headers
    assert_response 401
    @agent.update_column(:active, true)
  end

  def test_throttled_api_request_invalid_json
    old_v2_api_consumed_limit = get_key(v2_api_key).to_i
    old_v1_api_consumed_limit = get_key(api_key).to_i
    post '/api/discussions/categories', '{"category": {"name": "true"', @write_headers
    assert_response 400
    response.body.must_match_json_expression(invalid_json_error_pattern)
    new_v2_api_consumed_limit = get_key(v2_api_key).to_i
    new_v1_api_consumed_limit = get_key(api_key).to_i
    assert_equal old_v2_api_consumed_limit + 1, new_v2_api_consumed_limit
    assert_equal old_v1_api_consumed_limit, new_v1_api_consumed_limit
    response.headers.exclude?('X-Freshdesk-API-Version')
  end

  def test_throttled_api_request_invalid_content_type
    old_v2_api_consumed_limit = get_key(v2_api_key).to_i
    old_v1_api_consumed_limit = get_key(api_key).to_i
    post '/api/discussions/categories', '{"category": {"name": "true"}}', @headers.merge('CONTENT_TYPE' => 'text/plain')
    assert_response 415
    response.body.must_match_json_expression(un_supported_media_type_error_pattern)
    new_v2_api_consumed_limit = get_key(v2_api_key).to_i
    new_v1_api_consumed_limit = get_key(api_key).to_i
    assert_equal old_v2_api_consumed_limit + 1, new_v2_api_consumed_limit
    assert_equal old_v1_api_consumed_limit, new_v1_api_consumed_limit
    response.headers.exclude?('X-Freshdesk-API-Version')
  end

  def test_throttled_invalid_accept_header_request
    old_v2_api_consumed_limit = get_key(v2_api_key).to_i
    old_v1_api_consumed_limit = get_key(api_key).to_i
    get 'api/discussions/categories', nil, @headers.merge('HTTP_ACCEPT' => 'application/vnd.freshdesk.f3')
    assert_response 406
    new_v2_api_consumed_limit = get_key(v2_api_key).to_i
    new_v1_api_consumed_limit = get_key(api_key).to_i
    assert_equal old_v2_api_consumed_limit + 1, new_v2_api_consumed_limit
    assert_equal old_v1_api_consumed_limit, new_v1_api_consumed_limit
    response.headers.exclude?('X-Freshdesk-API-Version')
  end

  def test_throttled_valid_request_with_api_limit_constant
    old_v2_api_consumed_limit = get_key(v2_api_key).to_i
    old_v1_api_consumed_limit = get_key(api_key).to_i
    remove_key(account_key)
    remove_key(default_key)
    remove_key(plan_key(@account.subscription.subscription_plan_id))
    get '/api/discussions/categories', nil, @headers
    assert_response 200
    new_v2_api_consumed_limit = get_key(v2_api_key).to_i
    new_v1_api_consumed_limit = get_key(api_key).to_i
    assert_equal old_v2_api_consumed_limit + 1, new_v2_api_consumed_limit
    assert_equal old_v1_api_consumed_limit, new_v1_api_consumed_limit
    assert_equal '3000', response.headers['X-RateLimit-Total']
    assert_equal 'latest=v2; requested=v2', response.headers['X-Freshdesk-API-Version']
    remaining_limit = 3000 - new_v2_api_consumed_limit.to_i
    assert_equal remaining_limit.to_s, response.headers['X-RateLimit-Remaining']
    assert_equal '1', response.headers['X-RateLimit-Used']
  end

  def test_throttled_valid_request_with_default_api_limit
    old_v2_api_consumed_limit = get_key(v2_api_key).to_i
    old_v1_api_consumed_limit = get_key(api_key).to_i
    remove_key(account_key)
    remove_key(plan_key(@account.subscription.subscription_plan_id))
    get '/api/v2/discussions/categories', nil, @headers
    assert_response 200
    new_v2_api_consumed_limit = get_key(v2_api_key).to_i
    new_v1_api_consumed_limit = get_key(api_key).to_i
    assert_equal old_v2_api_consumed_limit + 1, new_v2_api_consumed_limit
    assert_equal old_v1_api_consumed_limit, new_v1_api_consumed_limit
    assert_equal '400', response.headers['X-RateLimit-Total']
    remaining_limit = 400 - new_v2_api_consumed_limit.to_i
    assert_equal remaining_limit.to_s, response.headers['X-RateLimit-Remaining']
    assert_equal '1', response.headers['X-RateLimit-Used']
    assert_equal 'latest=v2; requested=v2', response.headers['X-Freshdesk-API-Version']
  end

  def test_throttled_valid_request_with_plan_api_limit
    old_v2_api_consumed_limit = get_key(v2_api_key).to_i
    old_v1_api_consumed_limit = get_key(api_key).to_i
    remove_key(account_key)
    get '/api/v2/discussions/categories', nil, @headers
    assert_response 200
    new_v2_api_consumed_limit = get_key(v2_api_key).to_i
    new_v1_api_consumed_limit = get_key(api_key).to_i
    assert_equal old_v2_api_consumed_limit + 1, new_v2_api_consumed_limit
    assert_equal old_v1_api_consumed_limit, new_v1_api_consumed_limit
    assert_equal '200', response.headers['X-RateLimit-Total']
    remaining_limit = 200 - new_v2_api_consumed_limit.to_i
    assert_equal remaining_limit.to_s, response.headers['X-RateLimit-Remaining']
    assert_equal '1', response.headers['X-RateLimit-Used']
    assert_equal 'latest=v2; requested=v2', response.headers['X-Freshdesk-API-Version']
  end

  def test_throttled_valid_request_with_plan_api_limit_with_more_than_one_credit
    old_v2_api_consumed_limit = get_key(v2_api_key).to_i
    old_v1_api_consumed_limit = get_key(api_key).to_i
    remove_key(account_key)
    id = (Helpdesk::Ticket.first || create_ticket).display_id
    skip_bullet { get "/api/v2/tickets/#{id}?include=notes", nil, @headers }
    assert_response 200
    new_v2_api_consumed_limit = get_key(v2_api_key).to_i
    new_v1_api_consumed_limit = get_key(api_key).to_i
    assert_equal old_v2_api_consumed_limit + 2, new_v2_api_consumed_limit
    assert_equal old_v1_api_consumed_limit, new_v1_api_consumed_limit
    assert_equal '200', response.headers['X-RateLimit-Total']
    remaining_limit = 200 - new_v2_api_consumed_limit.to_i
    assert_equal remaining_limit.to_s, response.headers['X-RateLimit-Remaining']
    assert_equal '2', response.headers['X-RateLimit-Used']
    assert_equal 'latest=v2; requested=v2', response.headers['X-Freshdesk-API-Version']
  end

  def test_not_found_resource_throttled_version_in_path
    old_v2_api_consumed_limit = get_key(v2_api_key).to_i
    old_v1_api_consumed_limit = get_key(api_key).to_i
    remove_key(account_key)
    get '/api/discussions/categories/9999', nil, @headers
    assert_response 404
    new_v2_api_consumed_limit = get_key(v2_api_key).to_i
    new_v1_api_consumed_limit = get_key(api_key).to_i
    assert_equal old_v2_api_consumed_limit + 1, new_v2_api_consumed_limit
    assert_equal old_v1_api_consumed_limit, new_v1_api_consumed_limit
    assert_equal '200', response.headers['X-RateLimit-Total']
    remaining_limit = 200 - new_v2_api_consumed_limit.to_i
    assert_equal remaining_limit.to_s, response.headers['X-RateLimit-Remaining']
    assert_equal '1', response.headers['X-RateLimit-Used']
    response.headers.exclude?('X-Freshdesk-API-Version')
  end

  def test_not_found_resource_throttled_version_in_header
    old_v2_api_consumed_limit = get_key(v2_api_key).to_i
    old_v1_api_consumed_limit = get_key(api_key).to_i
    remove_key(account_key)
    get 'api/discussions/categories/9999', nil, @headers.merge(Accept: 'application/vnd.freshdesk.v2')
    assert_response 404
    new_v2_api_consumed_limit = get_key(v2_api_key).to_i
    new_v1_api_consumed_limit = get_key(api_key).to_i
    assert_equal old_v2_api_consumed_limit + 1, new_v2_api_consumed_limit
    assert_equal old_v1_api_consumed_limit, new_v1_api_consumed_limit
    assert_equal '200', response.headers['X-RateLimit-Total']
    remaining_limit = 200 - new_v2_api_consumed_limit.to_i
    assert_equal remaining_limit.to_s, response.headers['X-RateLimit-Remaining']
    assert_equal '1', response.headers['X-RateLimit-Used']
    response.headers.exclude?('X-Freshdesk-API-Version')
  end

  def test_not_found_path_throttled_without_passing_routes
    Middleware::TrustedIp.any_instance.stubs(:call).returns([404, {}, ['']])
    remove_key(account_key)
    get 'api/v2/discussions/categories/9999', nil, @headers.merge(Accept: 'application/vnd.freshdesk.v2')
    assert_response 404
    assert response.headers.exclude?('X-Freshdesk-API-Version')

    Middleware::TrustedIp.any_instance.stubs(:call).returns([404, {}, ['']])
    remove_key(account_key)
    get 'api/discussions/categories/9999', nil, @headers.merge(Accept: 'application/vnd.freshdesk.v3')
    assert_response 404
    assert response.headers.exclude?('X-Freshdesk-API-Version')

    remove_key(account_key)
    get 'api/v2/discussions/categories/9999', nil, @headers
    assert_response 404
    assert response.headers.exclude?('X-Freshdesk-API-Version')

    remove_key(account_key)
    get 'api/v3/discussions/categories/9999', nil, @headers
    assert_response 404
    assert response.headers.exclude?('X-Freshdesk-API-Version')

    remove_key(account_key)
    get 'api/vr/discussions/categories/9999', nil, @headers
    assert_response 404
    assert response.headers.exclude?('X-Freshdesk-API-Version')
  end

  def test_throttled_valid_request_with_account_api_limit
    old_v2_api_consumed_limit = get_key(v2_api_key).to_i
    old_v1_api_consumed_limit = get_key(api_key).to_i
    get '/api/discussions/categories', nil, @headers
    assert_response 200
    new_v2_api_consumed_limit = get_key(v2_api_key).to_i
    new_v1_api_consumed_limit = get_key(api_key).to_i
    assert_equal old_v2_api_consumed_limit + 1, new_v2_api_consumed_limit
    assert_equal old_v1_api_consumed_limit, new_v1_api_consumed_limit
    assert_equal 500.to_s, response.headers['X-RateLimit-Total']
    remaining_limit = 500 - new_v2_api_consumed_limit.to_i
    assert_equal remaining_limit.to_s, response.headers['X-RateLimit-Remaining']
    assert_equal '1', response.headers['X-RateLimit-Used']
    assert_equal 'latest=v2; requested=v2', response.headers['X-Freshdesk-API-Version']
  end

  def test_last_api_request
    old_api_consumed_limit = get_key(v2_api_key).to_i
    set_key(v2_api_key, 500 - 1)
    get '/api/v2/discussions/categories', nil, @headers
    new_api_consumed_limit = get_key(v2_api_key).to_i
    set_key(v2_api_key, old_api_consumed_limit, nil)
    assert_response 200
    assert_equal 500, new_api_consumed_limit
    assert_equal 500.to_s, response.headers['X-RateLimit-Total']
    assert_equal '0', response.headers['X-RateLimit-Remaining']
    assert_equal '1', response.headers['X-RateLimit-Used']
    assert_equal 'latest=v2; requested=v2', response.headers['X-Freshdesk-API-Version']
  end

  def test_limit_exceeded_api_request
    old_api_consumed_limit = get_key(v2_api_key).to_i
    set_key(v2_api_key, 500, nil)
    get '/api/discussions/categories', nil, @headers
    new_api_consumed_limit = get_key(v2_api_key).to_i
    set_key(v2_api_key, old_api_consumed_limit, nil)
    assert_response 429
    assert_equal 501, new_api_consumed_limit
    assert_equal String, response.headers['Retry-After'].class
    assert response.headers.exclude?('X-RateLimit-Total')
    assert response.headers.exclude?('X-RateLimit-Remaining')
    assert response.headers.exclude?('X-Freshdesk-API-Version')
  end

  def test_get_with_filters_numeric
    user_id = add_new_user(@account).id
    Helpdesk::Ticket.update_all(requester_id: @agent.id)
    Helpdesk::Ticket.first.update_column(:requester_id, user_id)
    skip_bullet do
      get "/api/tickets?requester_id=#{user_id}", nil, @headers
    end
    assert_response 200
    result = parse_response(@response.body)
    assert_equal Array, result.class
    assert_equal 1, result.count
  end

  # def test_get_with_filters_boolean
  #   Helpdesk::TimeSheet.update_all(billable: true)
  #   Helpdesk::TimeSheet.first.update_column(:billable, false)
  #   get "/api/time_entries?billable=false", nil, @headers
  #   assert_response 200
  #   result = parse_response(@response.body)
  #   assert_equal Array, result.class
  #   assert_equal 1, result.count
  # end

  def test_multipart_data_for_not_allowed_route
    headers, params = encode_multipart('name' => Faker::Name.name)
    skip_bullet do
      post '/api/discussions/categories', params, @headers.merge(headers)
    end
    assert_response 415
    response.body.must_match_json_expression(un_supported_media_type_error_pattern)
  end

  def test_used_api_limit
    ticket = Helpdesk::Ticket.last || create_ticket(email: 'test@abc.com')
    get "/api/tickets/#{ticket.display_id}", nil, @headers
    assert_equal '1', response.headers['X-RateLimit-Used']

    get "/api/tickets/#{ticket.display_id}?include=notes", nil, @headers
    assert_equal '2', response.headers['X-RateLimit-Used']
  end

  def test_v2_incremented_api_limit
    old_v2_api_consumed_limit = get_key(v2_api_key).to_i
    old_api_consumed_limit = get_key(api_key).to_i
    ticket = Helpdesk::Ticket.last || create_ticket(email: 'test@abc.com')
    get "api/tickets/#{ticket.display_id}", nil, @headers

    v2_api_consumed_limit = get_key(v2_api_key).to_i
    api_consumed_limit = get_key(api_key).to_i

    assert_equal old_v2_api_consumed_limit + 1, v2_api_consumed_limit
    assert_equal old_api_consumed_limit, api_consumed_limit

    get "/api/tickets/#{ticket.display_id}?include=notes", nil, @headers

    v2_api_consumed_limit = get_key(v2_api_key).to_i
    assert_equal old_v2_api_consumed_limit + 3, v2_api_consumed_limit
  end

  def test_cache_store_nil_jbuilder
    ApiDiscussions::CategoriesController.any_instance.stubs(:perform_caching).returns(true)
    ApiDiscussions::CategoriesController.any_instance.stubs(:cache_store).returns(nil)
    get '/api/discussions/categories.json', nil, @headers
    ApiDiscussions::CategoriesController.any_instance.unstub(:cache_store)
    ApiDiscussions::CategoriesController.any_instance.unstub(:perform_caching)
    pattern = @account.forum_categories.map { |fc| forum_category_pattern(fc) }
    match_json(pattern)
    assert_response 200
  end

  def test_caching_enabled_memcache_down_jbuilder
    ApiDiscussions::CategoriesController.any_instance.stubs(:perform_caching).returns(true)
    get '/api/discussions/categories.json', nil, @headers
    ApiDiscussions::CategoriesController.any_instance.unstub(:perform_caching)
    pattern = @account.forum_categories.map { |fc| forum_category_pattern(fc) }
    match_json(pattern)
    assert_response 200
  end

  def test_throttled_valid_request_with_plan_api_limit_changed
    old_plan = @account.subscription.subscription_plan
    enable_cache do
      new_plan = SubscriptionPlan.find(3)
      set_key(plan_key(3), 230, nil)
      remove_key(account_key)
      Subscription.fetch_by_account_id(@account.id) # setting memcache key

      @account.subscription.update_attribute(:subscription_plan_id, new_plan.id)
      @account.reload.subscription.reload.subscription_plan

      get '/api/v2/discussions/categories', nil, @headers
      assert_response 200
      assert_equal '230', response.headers['X-RateLimit-Total']
    end
  ensure
    @account.subscription.update_column(:subscription_plan_id, old_plan.id)
  end

  def test_throttler_with_redis_down
    remove_key(v2_api_key)
    rate_limit_instance = $rate_limit
    $rate_limit = mock('Redis Client Instance')
    get '/api/v2/discussions/categories', nil, @headers
    assert_response 200
    $rate_limit = rate_limit_instance
    assert_equal '3000', response.headers['X-RateLimit-Total']
    assert_equal '3000', response.headers['X-RateLimit-Remaining']
    assert_equal '1', response.headers['X-RateLimit-Used']
    assert_nil get_key(v2_api_key)
    assert_equal 'latest=v2; requested=v2', response.headers['X-Freshdesk-API-Version']
  ensure
    $rate_limit = rate_limit_instance
  end

  def test_throttler_with_expiry_not_set_properly
    old_api_consumed_limit = get_key(v2_api_key).to_i
    remove_key(v2_api_key)
    set_key(v2_api_key, '5000', nil)
    get '/api/v2/discussions/categories', nil, @headers
    set_key(v2_api_key, old_api_consumed_limit, nil)
    assert_response 429
    assert_equal '-1', response.headers['Retry-After']
  end

  def test_expiry_condition
    # expiring the expiry key: one hour has passed
    remove_key(v2_api_key)

    id = (Helpdesk::Ticket.first || create_ticket).display_id
    # first call after expiry
    skip_bullet { get "/api/v2/tickets/#{id}?include=notes", nil, @headers }
    assert_response 200

    assert_equal 2, get_key(v2_api_key).to_i
  end

  def test_skipped_subdomains
    ShardMapping.any_instance.stubs(:account_id).returns(@account.id)
    Middleware::FdApiThrottler.any_instance.stubs(:account_id).returns(@account.id)
    old_api_consumed_limit = get_key(api_key).to_i
    get '/groups.json', nil, @headers.merge('HTTP_HOST' => 'billing.junk.com')
    api_consumed_limit = get_key(api_key).to_i

    assert_response 404
    assert_equal old_api_consumed_limit, api_consumed_limit

    old_api_v2_consumed_limit = get_key(v2_api_key).to_i
    get 'api/discussions/categories.json', nil, @headers.merge('HTTP_HOST' => 'billing.junk.com')
    api_v2_consumed_limit = get_key(v2_api_key).to_i
    assert_response 404
    assert_equal old_api_v2_consumed_limit + 1, api_v2_consumed_limit

    get 'api/discussions/categories.json', nil, @headers.merge('HTTP_HOST' => 'billing.freshdesk.com')
    new_api_v2_consumed_limit = get_key(v2_api_key).to_i
    assert_response 404
    assert_equal api_v2_consumed_limit, new_api_v2_consumed_limit
  ensure
    ShardMapping.unstub(:account_id)
    Middleware::FdApiThrottler.any_instance.unstub(:account_id)
  end

  def test_shard_blocked_response
    ShardMapping.any_instance.stubs(:not_found?).returns(true)
    get 'api/discussions/categories', nil, @headers
    assert_response 404
    assert_equal ' ', @response.body
    ShardMapping.any_instance.unstub(:not_found?)
  end

  def test_pagination_with_invalid_datatype_string
    get 'api/discussions/categories?page=x&per_page=x', nil, @headers
    match_json([bad_request_error_pattern('page', :data_type_mismatch, data_type: 'Positive Integer'),
                bad_request_error_pattern('per_page', :per_page_data_type_mismatch, max_value: 100)])
    assert_response 400
  end

  def test_pagination_with_blank_values
    get 'api/discussions/categories?page=&per_page=', nil, @headers
    match_json([bad_request_error_pattern('page', :data_type_mismatch, data_type: 'Positive Integer'),
                bad_request_error_pattern('per_page', :per_page_data_type_mismatch, max_value: 100)])
    assert_response 400
  end

  def test_pagination_with_invalid_value
    get 'api/discussions/categories?page=0&per_page=0', nil, @headers
    match_json([bad_request_error_pattern('page', :invalid_number, data_type: 'Positive Integer'),
                bad_request_error_pattern('per_page', :per_page_invalid_number, max_value: 100)])
    assert_response 400
  end

  def test_pagination_with_invalid_negative_value
    get 'api/discussions/categories?page=-1&per_page=-1', nil, @headers
    match_json([bad_request_error_pattern('page', :invalid_number, data_type: 'Positive Integer'),
                bad_request_error_pattern('per_page', :per_page_invalid_number, max_value: 100)])
    assert_response 400
  end

  def test_pagination_with_invalid_datatype_array
    get 'api/discussions/categories?page[]=1&per_page[]=1', nil, @headers
    match_json([bad_request_error_pattern('page', :invalid_field),
                bad_request_error_pattern('per_page', :invalid_field)])
    assert_response 400
  end

  def test_pagination_with_per_page_exceeding_max_value
    get 'api/discussions/categories?page=922337203685&per_page=101', nil, @headers
    match_json([bad_request_error_pattern('per_page', :per_page_invalid_number, max_value: 100)])
    assert_response 400

    get 'api/discussions/categories?page=9223372036854775808&per_page=100', nil, @headers
    match_json([bad_request_error_pattern('page', :page_invalid_offset, max_value: 91_320_515_216_383_919)])
    assert_response 400

    get 'api/discussions/categories?page=91320515216383919&per_page=100', nil, @headers
    assert_response 200
  end

  def test_unexpected_range_error
    Sharding.stubs(:select_shard_of).raises(RangeError)
    get '/api/discussions/categories', nil, @headers
    assert_response 500
    response.body.must_match_json_expression(request_error_pattern(:internal_error))
  end

  def test_pagination_with_valid_values
    get 'api/discussions/categories?page=1000&per_page=100', nil, @headers
    assert_response 200
  end

  def test_invalid_domain_with_no_shard
    ShardMapping.stubs(:lookup_with_domain).returns(nil)
    ApiDiscussions::CategoriesController.any_instance.expects(:current_shard).once
    post '/api/discussions/categories', { 'name' => 'testdd_truested_ip' }.to_json, @write_headers
    assert_response 404
  ensure
    ShardMapping.unstub(:lookup_with_domain)
    ApiDiscussions::CategoriesController.any_instance.unstub(:current_shard)
  end

  def test_active_record_not_found_error
    error = ActiveRecord::RecordNotFound.new
    error.set_backtrace(['a', 'b'])
    ApiDiscussions::CategoriesController.any_instance.stubs(:set_time_zone).raises(error)
    ApiDiscussions::CategoriesController.any_instance.expects(:notify_new_relic_agent).with(error, description: 'ActiveRecord::RecordNotFound error occured while processing api request').once
    post '/api/discussions/categories', { 'name' => 'testdd_truested_ip' }.to_json, @write_headers
    assert_response 500
  ensure
    ApiDiscussions::CategoriesController.any_instance.unstub(:set_time_zone, :notify_new_relic_agent)
  end
end
