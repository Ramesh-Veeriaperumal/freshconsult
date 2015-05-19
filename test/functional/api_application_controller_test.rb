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
    error_array = { 'name' => 'invalid_field', 'test' => 'invalid_field' }
    @controller.stubs(:render_error).with(error_array).returns(true).once
    @controller.send(:invalid_field_handler, ActionController::UnpermittedParameters.new(['name', 'test']))
  end

  def test_missing_field_handler
    error_array = { 'name' => 'missing_field' }
    @controller.stubs(:render_error).with(error_array).returns(true).once
    @controller.send(:missing_field_handler, ActionController::ParameterMissing.new('name'))
  end

  def test_cname
    actual = controller.send(:cname)
    assert_equal controller.controller_name.singularize, actual
  end

  def test_paginate_options_returns_default_options
    params = ActionController::Parameters.new
    controller.params = params
    actual = controller.send(:paginate_options)
    assert_equal ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page], actual[:per_page]
    assert_equal ApiConstants::DEFAULT_PAGINATE_OPTIONS[:page], actual[:page]
  end

  def test_paginate_options_returns_default_options_if_per_page_exceeds_limit
    params = ActionController::Parameters.new(
      per_page: (ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page] + 1),
      page: Random.rand(11))
    controller.params = params
    actual = controller.send(:paginate_options)
    assert_equal ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page], actual[:per_page]
    assert_equal params[:page], actual[:page]
  end

  def test_paginate_options_returns_per_page_options_if_limit_does_not_exceed
    params = ActionController::Parameters.new(
      per_page: (ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page] - 1),
      page: Random.rand(11))
    controller.params = params
    actual = controller.send(:paginate_options)
    assert_equal params[:per_page], actual[:per_page]
    assert_equal params[:page], actual[:page]
  end

  def test_build_object
    @controller.stubs(:scoper).returns(Account.current.forum_categories)
    @controller.stubs(:cname).returns('category')
    params = { 'category' => { 'name' => 'test' } }
    @controller.params = params
    @controller.send(:build_object)
    actual = @controller.instance_variable_get(:@category)
    assert_equal actual, @controller.instance_variable_get(:@item)
    assert_not_nil actual
    assert_not_nil @controller.instance_variable_get(:@item)
    assert_equal 'test', actual.name
  end
end
