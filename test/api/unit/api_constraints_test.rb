require_relative '../test_helper'

class ApiConstraintsTest < ActionView::TestCase
  def test_api_constraint_instance
    constraint = ApiConstraints.new(version: '2')
    assert_equal '2', constraint.instance_variable_get(:@version)
  end

  def test_accept_header_with_version
    request = ActionDispatch::TestRequest.new
    request.accept = ['application/vnd.freshdesk.v2']
    constraint = ApiConstraints.new(version: '2')
    match = constraint.matches?(request)
    assert_equal true, match
  end

  def test_accept_header_wrong_version
    request = ActionDispatch::TestRequest.new
    request.accept = ['application/vnd.freshdesk.v3']
    constraint = ApiConstraints.new(version: '2')
    match = constraint.matches?(request)
    assert_equal false, match
  end

  def test_no_accept_header
    request = ActionDispatch::TestRequest.new
    constraint = ApiConstraints.new(version: '2')
    match = constraint.matches?(request)
    assert_nil match
  end
end
