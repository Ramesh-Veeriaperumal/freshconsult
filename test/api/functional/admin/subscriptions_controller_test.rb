require_relative '../../test_helper'
class Admin::SubscriptionsControllerTest < ActionController::TestCase
  def test_vaild_show
    get :show, construct_params(version: 'private')
    assert_response 200
  end

  def test_show_no_privilege
    User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
    get :show, construct_params(version: 'private')
    assert_response 403
  end
end