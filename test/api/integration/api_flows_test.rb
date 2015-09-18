require_relative '../test_helper'

class ApiFlowsTest < ActionDispatch::IntegrationTest
  include Helpers::DiscussionsHelper

  def test_json_format
    get '/api/discussions/categories.json', nil, @headers
    assert_response :success
    assert_equal Array, parse_response(@response.body).class
  end

  def test_no_format
    get '/api/discussions/categories', nil, @headers
    assert_response :success
    assert_equal Array, parse_response(@response.body).class
  end

  def test_non_json_format
    get '/api/discussions/categories.js', nil, @headers
    assert_response :not_found
    assert_equal ' ', @response.body
  end

  def test_no_route
    put '/api/discussions/category', '{"name": "true"}', @write_headers
    assert_response :not_found
    assert_equal ' ', @response.body
  end

  def test_method_not_allowed
    post '/api/discussions/categories/1', '{"name": "true"}', @write_headers
    assert_response :method_not_allowed
    response.body.must_match_json_expression(base_error_pattern('method_not_allowed', methods: 'GET, PUT, DELETE'))
    assert_equal 'GET, PUT, DELETE', response.headers['Allow']
  end

  def test_invalid_json
    post '/api/discussions/categories', '{"category": {"name": "true"', @write_headers
    assert_response :bad_request
    response.body.must_match_json_expression(invalid_json_error_pattern)
  end

  def test_domain_not_ready
    Sharding.stubs(:select_shard_of).raises(DomainNotReady)
    post '/api/discussions/categories', '{"name": "testdd"}', @write_headers
    assert_response :not_found
    response.body.must_match_json_expression(message: String)
  end

  def test_trusted_ip_invalid
    Middleware::TrustedIp.any_instance.stubs(:trusted_ips_enabled?).returns(true)
    Middleware::TrustedIp.any_instance.stubs(:valid_ip).returns(false)
    post '/api/discussions/categories', '{"name": "testdd"}', @write_headers.merge('rack.session' => { 'user_credentials_id' => '22' })
    assert_response :forbidden
    response.body.must_match_json_expression(message: String)
  end

  def test_globally_blacklisted_ip_invalid
    GlobalBlacklistedIp.any_instance.stubs(:ip_list).returns(['127.0.0.1'])
    post '/api/discussions/categories', '{"name": "testdd"}', @write_headers
    GlobalBlacklistedIp.any_instance.unstub(:ip_list)
    assert_response :forbidden
    response.body.must_match_json_expression(message: String)
  end

  def test_unsupported_media_type_invalid_content_type
    post '/api/discussions/categories', '{"category": {"name": "true"}}', @headers.merge('CONTENT_TYPE' => 'text/plain')
    assert_response :unsupported_media_type
    response.body.must_match_json_expression(un_supported_media_type_error_pattern)
  end

  def test_unsupported_media_type_invalid_content_type_with_no_body
    post '/api/discussions/categories', nil, @headers.merge('CONTENT_TYPE' => 'text/plain')
    assert_response :unsupported_media_type
    response.body.must_match_json_expression(un_supported_media_type_error_pattern)
  end

  def test_multipart_valid_content_type
    skip_bullet do
      headers, params = encode_multipart({ 'email' => 'test@abc.com', 'subject' => 'Test Subject' }, 'attachments[]', File.join(Rails.root, 'test/api/fixtures/files/image33kb.jpg'), 'image/jpg', true)
      post '/api/tickets', params, @headers.merge(headers)
    end
    assert_response :created
    assert_equal Hash, parse_response(@response.body).class
  end

  def test_multipart_invalid_data_parsable
    skip_bullet do
      params = { 'email' => Faker::Internet.email, 'subject' => 'Test Subject' }.to_json
      post '/api/tickets', params, @headers.merge("CONTENT_TYPE" => "multipart/form-data")
    end
    assert_response :bad_request
  end

  def test_multipart_invalid_data_unparsable
    skip_bullet do
      headers, params = encode_multipart({ 'ticket' => {'email' => 'test@abc.com', 'subject' => 'Test Subject' }}, 'attachments', File.join(Rails.root, 'test/api/fixtures/files/image33kb.jpg'), 'image/jpg', false)
      post '/api/tickets', params, @headers.merge(headers)
    end
    assert_response :internal_server_error
  end

  def test_unsupported_media_type_without_content_type
    post '/api/discussions/categories', '{"category": {"name": "true"}}', @headers
    assert_response :unsupported_media_type
    response.body.must_match_json_expression(un_supported_media_type_error_pattern)
  end

  def test_unsupported_media_type_get_request
    get '/api/discussions/categories', nil, @headers
    assert_response :success
    assert_equal Array, parse_response(@response.body).class
  end

  def test_not_acceptable_invalid_type
    get '/api/discussions/categories', nil, @headers.merge('HTTP_ACCEPT' => 'application/xml')
    assert_response :not_acceptable
    response.body.must_match_json_expression(not_acceptable_error_pattern)
  end

  def test_not_acceptable_valid
    get '/api/discussions/categories', nil, @headers.merge('HTTP_ACCEPT' => '*/*')
    assert_response :success
  end

  def test_not_acceptable_valid_custom_header
    get '/api/discussions/categories', nil, @headers.merge('HTTP_ACCEPT' => 'application/vnd.freshdesk.v2')
    assert_response :success
  end

  def test_not_acceptable_valid_json_type
    get '/api/discussions/categories', nil,  @headers.merge('HTTP_ACCEPT' => 'application/json')
    assert_response :success
  end

  def test_not_valid_fd_domain
    without_proper_fd_domain do
      get '/api/discussions/categories', nil, headers
      assert_response :not_found
    end
  end

  def test_not_valid_environment
    stub_const(ApiConstants, 'DEMOSITE_URL', @account.full_domain) do
      get '/api/discussions/categories', nil, headers
      assert_response :not_found
    end
  end

  def test_account_suspended_json
    subscription = @account.subscription
    subscription.update_column(:state, 'suspended')
    post '/api/discussions/categories', nil, @write_headers
    response = parse_response(@response.body)
    assert_equal({ 'code' => 'account_suspended', 'message' => 'Your account has been suspended.' }, response)
    assert_response :forbidden
    subscription.update_column(:state, 'trial')
  end

  def test_day_pass_expired_json
    Agent.any_instance.stubs(:occasional).returns(true).once
    subscription = @account.subscription
    subscription.update_column(:state, 'active')
    get '/agents.json', nil, @write_headers
    response = parse_response(@response.body)
    assert_equal({ 'code' => 'access_denied', 'message' => 'You are not authorized to perform this action.' }, response)
    assert_response :forbidden
  end

  def test_authenticating_get_request
    ApiDiscussions::CategoriesController.any_instance.expects(:authenticate_with_http_basic).never
    get '/api/discussions/categories', nil, @headers
  end

  def test_authenticating_post_request_with_password
    ApiDiscussions::CategoriesController.expects(:current_user_session).never
    @write_headers = set_custom_auth_headers(@write_headers, @agent.reload.email, 'test')
    post '/api/discussions/categories', v2_category_payload, @write_headers
    assert_response :created
  end

  def test_authenticating_post_request_with_consecutive_invalid_pwd
    flc = @agent.failed_login_count || 0
    pt = @agent.perishable_token
    ApiDiscussions::CategoriesController.expects(:current_user_session).never
    @write_headers = set_custom_auth_headers(@write_headers, @agent.reload.email, 'tester')
    post '/api/discussions/categories', v2_category_payload, @write_headers
    assert_response :unauthorized
    assert_equal flc + 1, @agent.reload.failed_login_count
    assert pt != @agent.perishable_token

    post '/api/discussions/categories', v2_category_payload, @write_headers
    assert_response :unauthorized
    assert_equal flc + 2, @agent.reload.failed_login_count

    @write_headers = set_custom_auth_headers(@write_headers, @agent.email, 'test')
    post '/api/discussions/categories', v2_category_payload, @write_headers
    assert_response :created
    assert_equal 0, @agent.reload.failed_login_count
  end

  def test_authenticating_get_request_with_consecutive_invalid_pwd
    flc = @agent.failed_login_count || 0
    pt = @agent.perishable_token

    @headers = set_custom_auth_headers(@headers, @agent.reload.email, 'tes')
    get '/api/discussions/categories', nil, @headers
    assert_response :unauthorized
    assert_equal flc + 1, @agent.reload.failed_login_count
    assert pt != @agent.perishable_token

    get '/api/discussions/categories', nil, @headers
    assert_response :unauthorized
    assert_equal flc + 2, @agent.reload.failed_login_count

    @headers = set_custom_auth_headers(@headers, @agent.email, 'test')
    get '/api/discussions/categories', nil, @headers
    assert_response :success
    assert_equal 0, @agent.reload.failed_login_count
  end

  def test_authenticating_post_request_with_token
    ApiDiscussions::CategoriesController.expects(:current_user_session).never
    post '/api/discussions/categories', v2_category_payload, @write_headers
    assert_response :created
  end

  def test_authenticating_post_request_with_invalid_token
    ApiDiscussions::CategoriesController.expects(:current_user_session).never
    @write_headers = set_custom_auth_headers(@write_headers, 'test', 'X')
    post '/api/discussions/categories', v2_category_payload, @write_headers
    assert_response :unauthorized
  end

  def test_valid_authentication_invalid_user
    ApiDiscussions::CategoriesController.expects(:current_user_session).never
    @agent.update_column(:active, false)
    post '/api/discussions/categories', v2_category_payload, @write_headers
    assert_response :unauthorized
    @agent.update_column(:active, true)
  end

  def test_not_throttled_api_request_invalid_json
    old_api_consumed_limit = get_others_redis_key(key).to_i
    post '/api/discussions/categories', '{"category": {"name": "true"', @write_headers
    assert_response :bad_request
    response.body.must_match_json_expression(invalid_json_error_pattern)
    new_api_consumed_limit = get_others_redis_key(key).to_i
    assert_equal old_api_consumed_limit, new_api_consumed_limit
    response.headers.exclude?('X-RateLimit-Limit')
    response.headers.exclude?('X-RateLimit-Remaining')
  end

  def test_not_throttled_api_request_invalid_content_type
    old_api_consumed_limit = get_others_redis_key(key).to_i
    post '/api/discussions/categories', '{"category": {"name": "true"}}', @headers.merge('CONTENT_TYPE' => 'text/plain')
    assert_response :unsupported_media_type
    response.body.must_match_json_expression(un_supported_media_type_error_pattern)
    new_api_consumed_limit = get_others_redis_key(key).to_i
    assert_equal old_api_consumed_limit, new_api_consumed_limit
    response.headers.exclude?('X-RateLimit-Limit')
    response.headers.exclude?('X-RateLimit-Remaining')
  end

  def test_not_throttled_web_request
    old_api_consumed_limit = get_others_redis_key(key).to_i
    get '/discussions/categories', nil, @headers
    new_api_consumed_limit = get_others_redis_key(key).to_i
    assert_equal old_api_consumed_limit, new_api_consumed_limit
    response.headers.exclude?('X-RateLimit-Limit')
    response.headers.exclude?('X-RateLimit-Remaining')
  end

  def test_throttled_valid_request_with_api_limit_not_present_in_redis
    old_api_consumed_limit = get_others_redis_key(key).to_i
    remove_others_redis_key(api_limit_key)
    get '/api/discussions/categories', nil, @headers
    assert_response :success
    new_api_consumed_limit = get_others_redis_key(key).to_i
    assert_equal old_api_consumed_limit + 1, new_api_consumed_limit
    assert_equal '100', response.headers['X-RateLimit-Limit']
    remaining_limit = 100 - new_api_consumed_limit.to_i
    assert_equal remaining_limit.to_s, response.headers['X-RateLimit-Remaining']
  end

  def test_throttled_valid_request_with_api_limit_present_in_redis
    old_api_consumed_limit = get_others_redis_key(key).to_i
    get '/api/discussions/categories', nil, @headers
    assert_response :success
    new_api_consumed_limit = get_others_redis_key(key).to_i
    assert_equal old_api_consumed_limit + 1, new_api_consumed_limit
    assert_equal @account.api_limit.to_s, response.headers['X-RateLimit-Limit']
    remaining_limit = @account.api_limit - new_api_consumed_limit.to_i
    assert_equal remaining_limit.to_s, response.headers['X-RateLimit-Remaining']
  end

  def test_last_api_request
    old_api_consumed_limit = get_others_redis_key(key).to_i
    set_others_redis_key(key, @account.api_limit - 1)
    get '/api/discussions/categories', nil, @headers
    new_api_consumed_limit = get_others_redis_key(key).to_i
    set_others_redis_key(key, old_api_consumed_limit)
    assert_response :success
    assert_equal @account.api_limit, new_api_consumed_limit
    assert_equal @account.api_limit.to_s, response.headers['X-RateLimit-Limit']
    assert_equal '0', response.headers['X-RateLimit-Remaining']
  end

  def test_limit_exceeded_api_request
    old_api_consumed_limit = get_others_redis_key(key).to_i
    set_others_redis_key(key, @account.api_limit, nil)
    get '/api/discussions/categories', nil, @headers
    new_api_consumed_limit = get_others_redis_key(key).to_i
    set_others_redis_key(key, old_api_consumed_limit)
    assert_equal 429, response.status
    assert_equal @account.api_limit, new_api_consumed_limit
    assert_equal @account.api_limit.to_s, response.headers['X-RateLimit-Limit']
    assert_equal '0', response.headers['X-RateLimit-Remaining']
  end

  EOL = "\015\012"  # "\r\n"
  # Encode params and image in multipart/form-data.
  def encode_multipart(params,image_param,image_file_path,content_type, encoding)
    headers={}
    parts=[]
    boundary="234092834029834092830498"
    params.each_pair do |key,val|
      parts.push %{Content-Disposition: form-data; }+
                 %{name="#{key}"#{EOL}#{EOL}#{val}#{EOL}}
    end
    image_part = \
      %{Content-Disposition: form-data; name="#{image_param}"; }+
      %{filename="#{File.basename(image_file_path)}"#{EOL}}+
      %{Content-Type: #{content_type}#{EOL}#{EOL}}
    file_read_params = encoding ? [image_file_path, encoding: "UTF-8"] : [image_file_path]
    image_part << File.read(*file_read_params) << EOL
    image_part = image_part.force_encoding("BINARY") if image_part.respond_to?(:force_encoding) if encoding
    parts.push(image_part)
    body = parts.join("--#{boundary}#{EOL}")
    body = "--#{boundary}#{EOL}" + body + "--#{boundary}--"+EOL
    headers['CONTENT_TYPE']="multipart/form-data; boundary=#{boundary}"
    [ headers , body.scrub! ]
  end
end
