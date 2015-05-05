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
end