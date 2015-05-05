require_relative '../test_helper'

class CatchJsonParseErrorsTest < ActionView::TestCase
  
  def env_for(url, opts={})
    Rack::MockRequest.env_for(url, opts)
  end
 
  def test_catch_json_parse_errors_for_json_content_type
    test_app = lambda { |env| [200, {'HTTP_HOST' => 'localhost'}, ['OK']] }
    catch_json_parse_error = Middleware::CatchJsonParseErrors.new(test_app)
    catch_json_parse_error.instance_variable_get(:@app).stubs(:call).raises(MultiJson::ParseError, "message")
    status, headers, response = catch_json_parse_error.call env_for('http://localhost.freshpo.com/api/v2/discussions/categories', 
      { 'HTTP_HOST' => "localhost.freshpo.com", "CONTENT-TYPE" => "application/json"})
    assert_equal 400, status
    assert_equal true, ["Content-Type"].all? {|key| headers.key? key }
    response.must_match_json_expression(invalid_json_error_pattern)
  end

  def test_catch_json_parse_errors_for_others
    test_app = lambda { |env| [200, {'HTTP_HOST' => 'localhost'}, ['OK']] }
    catch_json_parse_error = Middleware::CatchJsonParseErrors.new(test_app)
    catch_json_parse_error.instance_variable_get(:@app).stubs(:call).raises(MultiJson::ParseError, "message")
    assert_raises(MultiJson::ParseError) {  status, headers, response = catch_json_parse_error.call env_for('http://localhost.freshpo.com/api/v2/discussions/categories', 
      { 'HTTP_HOST' => "localhost.freshpo.com"}) }
  end

  def test_catch_json_parse_errors_valid
    test_app = lambda { |env| [200, {'HTTP_HOST' => 'localhost'}, ['OK']] }
    catch_json_parse_error = Middleware::CatchJsonParseErrors.new(test_app)
    catch_json_parse_error.instance_variable_get(:@app).stubs(:call).returns([200, {'HTTP_HOST' => 'localhost'}, ['OK']])
    assert_nothing_raised do
      status, headers, response = catch_json_parse_error.call env_for('http://localhost.freshpo.com/api/v2/discussions/categories', 
      { 'HTTP_HOST' => "localhost.freshpo.com"})
    end
  end
  
end