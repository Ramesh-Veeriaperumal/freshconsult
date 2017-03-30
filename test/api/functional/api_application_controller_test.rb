require_relative '../test_helper'

class ApiApplicationControllerTest < ActionController::TestCase
  def test_invalid_field_handler
    error_array = { 'name' => :invalid_field, 'test' => :invalid_field }
    @controller.expects(:render_errors).with(error_array).once
    @controller.send(:invalid_field_handler, ActionController::UnpermittedParameters.new(['name', 'test']))
  end

  def test_set_current_account_when_signature_error
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:api_current_user).raises(ActiveSupport::MessageVerifier::InvalidSignature)
    @controller.send(:set_current_account)
    assert_equal 401, response.status
    assert_equal request_error_pattern(:credentials_required).to_json, response.body
  end

  def test_api_current_user_failed_login_count_on_valid_pwd
    auth = ActionController::HttpAuthentication::Basic.encode_credentials(@agent.email, 'test')
    params = ActionController::Parameters.new('format' => 'json')
    controller.params = params
    @controller.request.env['HTTP_AUTHORIZATION'] = auth
    @agent.update_attribute(:failed_login_count, 1)
    @controller.send(:api_current_user)
    assert_equal 0, @agent.reload.failed_login_count
  end

  def test_api_current_user_failed_login_count_on_valid_api_key
    auth = ActionController::HttpAuthentication::Basic.encode_credentials(@agent.single_access_token, 'X')
    params = ActionController::Parameters.new('format' => 'json')
    controller.params = params
    @controller.request.env['HTTP_AUTHORIZATION'] = auth
    @agent.update_attribute(:failed_login_count, 1)
    @controller.send(:api_current_user)
    assert_equal 1, @agent.reload.failed_login_count
  end

  def test_invalid_field_handler_with_invalid_multi_part
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.request.env['RAW_POST_DATA'] = "{ \n \"requester_id\":1\n}"
    @controller.request.env['CONTENT_TYPE'] = 'multipart/form-data; charset=UTF-8'
    assert_nothing_raised do
      @controller.send(:invalid_field_handler, ActionController::UnpermittedParameters.new(["{ \n \"requester_id\":1\n}"]))
    end
    assert_equal response.status, 400
    assert_equal response.body, request_error_pattern(:invalid_multipart).to_json
  end

  def test_invalid_field_handler_with_invalid_parseable_json
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.request.env['RAW_POST_DATA'] = 'test junk'
    @controller.request.env['CONTENT_TYPE'] = 'application/json; charset=UTF-8'
    assert_nothing_raised do
      @controller.send(:invalid_field_handler, ActionController::UnpermittedParameters.new(['_json']))
    end
    assert_equal response.status, 400
    assert_equal response.body, request_error_pattern(:invalid_json).to_json
  end

  def test_record_not_unique_error
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.request.env['RAW_POST_DATA'] = 'test junk'
    @controller.request.env['CONTENT_TYPE'] = 'application/json; charset=UTF-8'
    assert_nothing_raised do
      error = ActiveRecord::RecordNotUnique.new('RecordNotUnique', 'Duplicate-Entry')
      error.set_backtrace(['a', 'b'])
      @controller.send(:duplicate_value_error, error)
    end
    assert_equal response.status, 409
    assert_equal response.body, request_error_pattern(:duplicate_value).to_json
  end

  def test_statement_invalid_error
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.request.env['RAW_POST_DATA'] = 'test junk'
    @controller.request.env['CONTENT_TYPE'] = 'application/json; charset=UTF-8'
    assert_nothing_raised do
      error = ActiveRecord::StatementInvalid.new
      error.set_backtrace(['a', 'b'])
      @controller.send(:db_query_error, error)
    end
    assert_equal response.status, 500
    assert_equal response.body, base_error_pattern(:internal_error).to_json
  end

  def test_notify_new_relic_agent
    @controller.request.env['ORIGINAL_FULLPATH'] = '/api/tickets'
    NewRelic::Agent.expects(:notice_error).with('Exception', uri: 'http://localhost.freshpo.com/api/tickets', custom_params: { method: 'GET', params: {}, x_request_id: nil }).once
    @controller.send(:notify_new_relic_agent, 'Exception')
  end

  def test_route_not_found_with_method_not_allowed
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.env['PATH_INFO'] = 'api/v2/tickets/1000'
    request = ActionDispatch::TestRequest.new
    request.request_method = 'POST'
    @controller.request = request
    params = ActionController::Parameters.new(version: 2)
    @controller.send(:route_not_found)
    assert_equal response.headers['Allow'], 'GET, PUT, DELETE'
    assert_equal response.status, 405
    assert_equal response.body, base_error_pattern(:method_not_allowed, methods: 'GET, PUT, DELETE', fired_method: 'POST').to_json
  end

  def test_route_not_found
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.env['PATH_INFO'] = 'api/v2/junk/1000'
    params = ActionController::Parameters.new(version: 2)
    @controller.send(:route_not_found)
    assert_nil response.headers['Allow']
    assert_equal response.status, 404
    assert_equal response.body, ' '
  end

  def test_cname
    actual = controller.send(:cname)
    assert_equal controller.controller_name.singularize, actual
  end

  def test_paginate_options_returns_default_options
    params = ActionController::Parameters.new
    controller.params = params
    actual = controller.send(:paginate_options)
    assert_equal ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page] + 1, actual[:per_page]
    assert_equal ApiConstants::DEFAULT_PAGINATE_OPTIONS[:page], actual[:page]
  end

  def test_paginate_options_returns_per_page_options_if_limit_does_not_exceed
    params = ActionController::Parameters.new(
      per_page: (ApiConstants::DEFAULT_PAGINATE_OPTIONS[:max_per_page] - 1),
      page: Random.rand(2..11))
    controller.params = params
    actual = controller.send(:paginate_options)
    assert_equal params[:per_page] + 1, actual[:per_page]
    assert_equal params[:page], actual[:page]
  end

  def test_build_object
    @controller.stubs(:scoper).returns(Account.current.forum_categories)
    @controller.stubs(:cname).returns('category')
    params = { 'category' => { 'name' => 'test' } }
    @controller.params = params
    @controller.send(:build_object)
    assert_not_nil @controller.instance_variable_get(:@item)
    assert_equal 'test', @controller.instance_variable_get(:@item).name
  end

  def test_validate_content_type_with_get_request
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    request = ActionDispatch::TestRequest.new
    request.request_method = 'GET'
    @controller.request = request
    @controller.send(:validate_content_type)
    assert response.body.blank?
  end

  def test_validate_content_type_with_json_post_request
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    request = ActionDispatch::TestRequest.new
    request.request_method = 'POST'
    request.env['CONTENT_TYPE'] = 'application/json'
    params = { 'category' => { 'name' => 'test' } }
    @controller.params = params
    @controller.request = request
    @controller.action_name = 'update'
    @controller.send(:validate_content_type)
    assert response.body.blank?
  end

  def test_validate_content_type_with_non_json_post_request
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    request = ActionDispatch::TestRequest.new
    request.request_method = 'POST'
    request.env['CONTENT_TYPE'] = 'application/xml'
    params = { 'category' => { 'name' => 'test' } }
    @controller.params = params
    @controller.request = request
    @controller.action_name = 'update'
    actual = @controller.send(:validate_content_type)
    assert_equal response.status, 415
    assert_equal response.body, request_error_pattern(:invalid_content_type, content_type: 'application/xml').to_json
  end

  def test_render_errors_with_errors_empty
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    request = ActionDispatch::TestRequest.new
    request.request_method = 'PUT'
    @controller.request = request

    assert_nothing_raised { @controller.send(:render_errors, []) }
    assert_equal response.status, 500
    assert_equal response.body, base_error_pattern(:internal_error).to_json
  end

  def test_render_custom_errors_with_errors_empty
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    request = ActionDispatch::TestRequest.new
    request.request_method = 'PUT'
    @controller.request = request

    assert_nothing_raised { @controller.send(:render_custom_errors, Topic.new) }
    assert_equal response.status, 500
    assert_equal response.body, base_error_pattern(:internal_error).to_json
  end

  def test_valid_jwt_token_authentication
    @account.launch(:api_jwt_auth)
    token = generate_jwt_token(1, 1, Time.now.to_i, Time.now.to_i)
    auth = ActionController::HttpAuthentication::Token.encode_credentials(token)
    @controller.request.env['HTTP_AUTHORIZATION'] = auth
    @controller.send(:api_current_user)
    current_user = @controller.instance_variable_get(:@current_user)
    assert_not_nil current_user
  end

  def test_already_used_jti_in_jwt_token_authentication
    @account.launch(:api_jwt_auth)
    jti = rand(234412121)
    token = generate_jwt_token(1, 1, jti, Time.now.to_i - 35)
    auth = ActionController::HttpAuthentication::Token.encode_credentials(token)
    @controller.request.env['HTTP_AUTHORIZATION'] = auth
    @controller.send(:api_current_user)
    current_user = @controller.instance_variable_get(:@current_user)
    assert_not_nil current_user

    @controller.instance_variable_set(:@current_user, nil)
    token = generate_jwt_token(1, 1, jti, Time.now.to_i - 34)
    auth = ActionController::HttpAuthentication::Token.encode_credentials(token)
    @controller.request.env['HTTP_AUTHORIZATION'] = auth
    @controller.send(:api_current_user)

    current_user = @controller.instance_variable_get(:@current_user)
    assert_nil current_user
  end

  def test_invalid_iat_in_jwt_token_authentication
    @account.launch(:api_jwt_auth)
    token = generate_jwt_token(1, 1, Time.now.to_i, 2*(Time.now.to_i))
    auth = ActionController::HttpAuthentication::Token.encode_credentials(token)
    @controller.request.env['HTTP_AUTHORIZATION'] = auth
    @controller.send(:api_current_user)
    current_user = @controller.instance_variable_get(:@current_user)
    assert_nil current_user
  end

  def test_jwt_authentication_using_same_token
    @account.launch(:api_jwt_auth)
    token = generate_jwt_token(1, 1,Time.now.to_i, Time.now.to_i)
    auth = ActionController::HttpAuthentication::Token.encode_credentials(token)
    @controller.request.env['HTTP_AUTHORIZATION'] = auth
    @controller.send(:api_current_user)
    current_user = @controller.instance_variable_get(:@current_user)
    assert_not_nil current_user
    @controller.instance_variable_set(:@current_user, nil)
    # auth again with the same token , this time it should be unsuccessful
    @controller.send(:api_current_user)
    current_user = @controller.instance_variable_get(:@current_user)
    assert_nil current_user
  end

end
