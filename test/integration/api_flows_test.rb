require_relative '../test_helper'

class ApiFlowsTest < ActionDispatch::IntegrationTest
  def test_json_format
    get "/api/discussions/categories.json", nil, @headers
    assert_response :success
    assert_equal 1, parse_json(response.body).size
  end

  def test_no_format
    get "/api/discussions/categories", nil, @headers
    assert_response :success
    assert_equal 1, parse_json(response.body).size
  end

  def test_non_json_format
    get "/api/discussions/categories.js", nil, @headers
    assert_response :not_found
    assert_equal 1, @response.body.size
  end

  def test_no_route
    put "/api/discussions/category", nil, @headers
    assert_response :not_found
    assert_equal 1, @response.body.size
  end

  def test_method_not_allowed
    get "/api/discussions/categories/1", nil, @headers
    assert_response :method_not_allowed
    response = parse_json(@response.body)
    assert_equal({"message"=> "Allowed methods are PUT, DELETE"}, response)
  end
end