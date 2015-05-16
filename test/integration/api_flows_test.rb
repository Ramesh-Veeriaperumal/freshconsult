require_relative '../test_helper'

class ApiFlowsTest < ActionDispatch::IntegrationTest
  def test_json_format
    get "/api/discussions/categories.json", nil, @headers
    assert_response :success
    assert_equal Array, parse_response(@response.body).class
  end

  def test_no_format
    get "/api/discussions/categories", nil, @headers
    assert_response :success
    assert_equal Array, parse_response(@response.body).class
  end

  def test_non_json_format
    get "/api/discussions/categories.js", nil, @headers
    assert_response :not_found
    assert_equal " ", @response.body
  end

  def test_no_route
    put "/api/discussions/category", nil, @headers
    assert_response :not_found
    assert_equal " ", @response.body
  end

  def test_method_not_allowed
    post "/api/discussions/categories/1", nil, @headers
    assert_response :method_not_allowed
    response.body.must_match_json_expression(base_error_pattern("method_not_allowed", :methods => "GET, PUT, DELETE"))
    assert_equal "GET, PUT, DELETE", response.headers["Allow"]
  end

  def test_invalid_json
    @headers["CONTENT_TYPE"] = 'application/json'
    post "/api/discussions/categories", '{"category": {"name": "true"', @headers
    assert_response :bad_request
    response.body.must_match_json_expression(invalid_json_error_pattern)
  end

  def test_unsupported_media_type_invalid_content_type
    @headers["CONTENT_TYPE"] = 'text/plain'
    post "/api/discussions/categories", '{"category": {"name": "true"}}', @headers
    assert_response :unsupported_media_type
    response.body.must_match_json_expression(un_supported_media_type_error_pattern)
  end

  def test_unsupported_media_type_without_content_type
    @headers.delete("CONTENT_TYPE")
    post "/api/discussions/categories", '{"category": {"name": "true"}}', @headers
    assert_response :unsupported_media_type
    response.body.must_match_json_expression(un_supported_media_type_error_pattern)
  end

  def test_unsupported_media_type_get_request
    @headers.delete("CONTENT_TYPE")
    get "/api/discussions/categories", nil, @headers
    assert_response :success
    assert_equal Array, parse_response(@response.body).class
  end
end