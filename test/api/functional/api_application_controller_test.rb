require_relative '../test_helper'

class ApiApplicationControllerTest < ActionController::TestCase
  def test_latest_version
    response = ActionDispatch::TestResponse.new
    controller.response = response
    params = ActionController::Parameters.new(version: 2)
    controller.params = params
    @controller.send(:response_headers)
    version_header = "current=#{ApiConstants::API_CURRENT_VERSION}; requested=#{params[:version]}"
    assert_equal true, response.headers.include?('X-Freshdesk-API-Version')
    assert_equal version_header, response.headers['X-Freshdesk-API-Version']
  end

  def test_invalid_field_handler
    error_array = { 'name' => ['invalid_field'], 'test' => ['invalid_field'] }
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
    auth = ActionController::HttpAuthentication::Basic.encode_credentials(@agent.single_access_token, 'X')
    @controller.request.env['HTTP_AUTHORIZATION'] = auth
    @agent.update_attribute(:failed_login_count, 1)
    @controller.send(:api_current_user)
    assert_equal 0, @agent.reload.failed_login_count
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

  def test_notify_new_relic_agent
    @controller.request.env['ORIGINAL_FULLPATH'] = "/api/tickets"
    NewRelic::Agent.expects(:notice_error).with("Exception",  {uri: @controller.request.original_url}).once
    @controller.send(:notify_new_relic_agent, "Exception")
  end

  def test_route_not_found_with_method_not_allowed
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.env['PATH_INFO'] = 'api/v2/tickets/1000'
    params = ActionController::Parameters.new(version: 2)
    @controller.send(:route_not_found)
    assert_equal response.headers['Allow'], 'GET, PUT, DELETE'
    assert_equal response.status, 405
    assert_equal response.body, base_error_pattern(:method_not_allowed, methods: 'GET, PUT, DELETE').to_json
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

  def test_paginate_options_returns_default_options_if_per_page_exceeds_limit
    params = ActionController::Parameters.new(
      per_page: (ApiConstants::DEFAULT_PAGINATE_OPTIONS[:max_per_page] + 1),
      page: Random.rand(11))
    controller.params = params
    actual = controller.send(:paginate_options)
    assert_equal ApiConstants::DEFAULT_PAGINATE_OPTIONS[:max_per_page] + 1, actual[:per_page]
    assert_equal params[:page], actual[:page]
  end

  def test_paginate_options_returns_per_page_options_if_limit_does_not_exceed
    params = ActionController::Parameters.new(
      per_page: (ApiConstants::DEFAULT_PAGINATE_OPTIONS[:max_per_page] - 1),
      page: Random.rand(11))
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
    actual = @controller.send(:validate_content_type)
    assert_equal response.status, 415
    assert_equal response.body, request_error_pattern(:invalid_content_type).to_json
  end
end
