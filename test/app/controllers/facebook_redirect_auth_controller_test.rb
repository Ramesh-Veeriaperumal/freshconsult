require_relative '../../api/test_helper'

class FacebookRedirectAuthControllerTest < ActionController::TestCase
  def test_complete_request
    FacebookRedirectAuthController.any_instance.stubs(:get_others_redis_key).returns('host_url')
    get :complete, controller_params(version: 'private', state: 'state', code: 'dummycode123#')
    assert_equal true, response.body.include?('dummycode123#')
    assert_response 302
  end

  def test_complete_request_failure
    FacebookRedirectAuthController.any_instance.stubs(:get_others_redis_key).returns('host_url')
    get :complete, controller_params(version: 'private')
    assert_equal true, response.body.include?('/admin/home')
    assert_response 302
  end

  def test_complete_request_no_redis_key
    FacebookRedirectAuthController.any_instance.stubs(:get_others_redis_key).returns(nil)
    get :complete, controller_params(version: 'private', state: 'state', code: 'dummycode123#')
    assert_equal true, response.body.include?('/admin/home')
    assert_response 302
  end
end
