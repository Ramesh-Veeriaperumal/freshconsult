require_relative '../test_helper'

class ApiFlowsTest < ActionDispatch::IntegrationTest
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
    put '/api/discussions/category', nil, @headers
    assert_response :not_found
    assert_equal ' ', @response.body
  end

  def test_method_not_allowed
    post '/api/discussions/categories/1', nil, @headers
    assert_response :method_not_allowed
    response.body.must_match_json_expression(base_error_pattern('method_not_allowed', methods: 'GET, PUT, DELETE'))
    assert_equal 'GET, PUT, DELETE', response.headers['Allow']
  end

  def test_invalid_json
    post '/api/discussions/categories', '{"category": {"name": "true"', @write_headers
    assert_response :bad_request
    response.body.must_match_json_expression(invalid_json_error_pattern)
  end

  def test_unsupported_media_type_invalid_content_type
    post '/api/discussions/categories', '{"category": {"name": "true"}}', @headers.merge('CONTENT_TYPE' => 'text/plain')
    assert_response :unsupported_media_type
    response.body.must_match_json_expression(un_supported_media_type_error_pattern)
  end

  def test_multipart_valid_content_type
    skip_bullet do
      post '/api/tickets', { 'ticket' => { 'email' => 'test@abc.com', 'subject' => 'Test Subject' } }, @headers.merge('CONTENT_TYPE' => 'multipart/form-data')
    end
    assert_response :created
    assert_equal Hash, parse_response(@response.body).class
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
    @write_headers = set_custom_auth_headers(@write_headers, @agent.email, 'test')
    post '/api/discussions/categories', v2_category_payload, @write_headers
    assert_response :created
  end

  def test_authenticating_post_request_with_consecutive_invalid_pwd
    flc = @agent.failed_login_count || 0
    pt = @agent.perishable_token
    ApiDiscussions::CategoriesController.expects(:current_user_session).never
    @write_headers = set_custom_auth_headers(@write_headers, @agent.email, 'tester')
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

    @headers = set_custom_auth_headers(@headers, @agent.email, 'tes')
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
end
