require_relative '../../../test_helper'

class Ember::Freshcaller::SettingsControllerTest < ActionController::TestCase

  def wrap_cname(_param)
    {}
  end

  def test_fetch_desktop_notification_setting
    @controller.stubs(:requires_feature).with(:freshcaller).returns(true)
    @controller.stubs(:get_integ_redis_key).returns(true)
    put :desktop_notification, construct_params(version: 'private')
    match_json(desktop_notification_disabled: true)
    assert_response 200
    ensure
    @controller.unstub(:requires_feature)
    @controller.unstub(:get_integ_redis_key)
  end

  def test_fetch_desktop_notification_setting_without_freshcaller_feature
    put :desktop_notification, construct_params(version: 'private')
    match_json(request_error_pattern(:require_feature, feature: 'freshcaller'.titleize))
    assert_response 403
  end

  def test_disable_desktop_notification_setting
    @controller.stubs(:requires_feature).with(:freshcaller).returns(true)
    @controller.stubs(:get_integ_redis_key).returns(true)
    put :desktop_notification, construct_params(version: 'private', disable: 'true')
    match_json({:desktop_notification_disabled => true})
    assert_response 200
    ensure
    @controller.unstub(:requires_feature)
    @controller.unstub(:get_integ_redis_key)
  end
end
