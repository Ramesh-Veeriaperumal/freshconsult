require_relative '../../test_helper'
class Ember::ConfigsControllerTest < ActionController::TestCase
  def setup
    super
    before_all
  end

  def teardown
    User.any_instance.unstub(:privilege?)
    Account.any_instance.unstub(:freshreports_analytics_enabled?)
  end

  def before_all
    @account = Account.first.make_current
    @user = User.current || add_new_user(@account).make_current
    Account.any_instance.stubs(:freshreports_analytics_enabled?).returns(true)
    User.any_instance.stubs(:privilege?).with(:view_analytics).returns(true)
  end

  def test_config_response
    get :show, controller_params(version: 'private', id: 'freshvisuals')
    assert_response 200
    end_point = JSON.parse(response.body)['url']
    payload_segment = end_point.split('.')[1]
    payload = JSON.parse(JWT.base64url_decode(payload_segment), symbolize_names: true)
    assert_equal payload[:firstName], @user.name
    assert_equal payload[:email], @user.email
    assert_equal payload[:userId], @user.id
  end

  def test_invalid_config_response
    get :show, controller_params(version: 'private', id: 'abc')
    assert_response 400
    match_json([bad_request_error_pattern("id", :"It should be one of these values: 'freshvisuals'")])
  end

  def test_config_response_with_feature_disabled
    Account.any_instance.stubs(:freshreports_analytics_enabled?).returns(false)
    get :show, controller_params(version: 'private', id: 'freshvisuals')
    assert_response 403
    match_json(request_error_pattern(:require_feature, feature: 'Freshreports Analytics'))
  end

  def test_config_response_without_privilege
    User.any_instance.stubs(:privilege?).with(:view_analytics).returns(false)
    get :show, controller_params(version: 'private', id: 'freshvisuals')
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end
end
