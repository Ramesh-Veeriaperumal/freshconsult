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
    User.any_instance.stubs(:time_zone).returns('Casablanca')
    User.any_instance.stubs(:language).returns('en')
    get :show, controller_params(version: 'private', id: 'freshvisuals')
    assert_response 200
    end_point = JSON.parse(response.body)['url']
    payload_segment = end_point.split('.')[1]
    payload = JSON.parse(JWT.base64url_decode(payload_segment), symbolize_names: true)
    assert_equal payload[:firstName], @user.name
    assert_equal payload[:email], @user.email
    assert_equal payload[:userId], @user.id
    assert_equal payload[:timezone], 'Africa/Casablanca'
    assert_equal payload[:language], 'en'
    assert_equal payload[:portalUrl], "#{@account.url_protocol}://#{@account.full_domain}"
    assert_equal payload[:page], 'home'
    assert_equal payload[:exp], payload[:iat] + FreshVisualsConfig['early_expiration'].to_i
  ensure
    User.any_instance.unstub(:time_zone)
    User.any_instance.unstub(:language)
  end

  def test_config_response_with_null_user_language
    User.any_instance.stubs(:language).returns(nil)
    Account.any_instance.stubs(:language).returns('ar')
    get :show, controller_params(version: 'private', id: 'freshvisuals')
    assert_response 200
    end_point = JSON.parse(response.body)['url']
    payload_segment = end_point.split('.')[1]
    payload = JSON.parse(JWT.base64url_decode(payload_segment), symbolize_names: true)
    assert_equal payload[:language], 'ar'
  ensure
    User.any_instance.unstub(:language)
    Account.any_instance.unstub(:language)
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
