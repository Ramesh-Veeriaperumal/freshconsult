require_relative '../test_helper'

class ApiConstraintsTest < ActionView::TestCase


  test "should return the api constraint object" do
    assert_not_nil ApiConstraints.new({:version => 1})
  end

  test "should return true if accept header version matches with the default version" do
    request = ActionDispatch::TestRequest.new
    request.accept = ["application/vnd.freshdesk.v1"]
    constraint = ApiConstraints.new({:version => 1})
    match = constraint.matches?(request)
    assert_equal match, true
  end

  test "should return false if accept header version doesn't match with the default version" do
    request = ActionDispatch::TestRequest.new
    request.accept = ["application/vnd.freshdesk.v2"]
    constraint = ApiConstraints.new({:version => 1})
    match = constraint.matches?(request)
    assert_equal match, false
  end

end