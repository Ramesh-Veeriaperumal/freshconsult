# frozen_string_literal: true

require_relative '../unit_test_helper'

class WidgetValidationTest < ActionView::TestCase
  include Dashboard::Custom::CustomDashboardConstants
  def test_freshdesk_scorecard_without_omni_dashboard_feature_without_source
    Account.stubs(:current).returns(Account.first)
    controller_params = { widget_type: WIDGET_MODULE_TOKEN_BY_NAME['scorecard'], name: 'scorecard1', config_data: {}, x: 1, y: 1, height: 1, width: 1 }
    item = nil
    widget = WidgetValidation.new(controller_params, item, true)
    widget.valid?(:create)
    error = widget.errors.full_messages
    assert_equal [], error
  ensure
    Account.unstub(:current)
  end

  def test_freshdesk_scorecard_with_omni_dashboard_feature_with_source
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:omni_channel_team_dashboard_enabled?).returns(true)
    controller_params = { widget_type: WIDGET_MODULE_TOKEN_BY_NAME['scorecard'], name: 'scorecard1', config_data: {}, x: 1, y: 1, height: 1, width: 1, source: 'freshdesk' }
    item = nil
    widget = WidgetValidation.new(controller_params, item, true)
    widget.valid?(:create)
    error = widget.errors.full_messages
    assert_equal [], error
  ensure
    Account.any_instance.unstub(:omni_channel_team_dashboard_enabled?)
    Account.unstub(:current)
  end

  def test_freshcaller_call_trend_without_omni_dashboard_feature
    Account.stubs(:current).returns(Account.first)
    controller_params = { widget_type: WIDGET_MODULE_TOKEN_BY_NAME['ms_call_trend'], name: 'scorecard1', config_data: {}, x: 1, y: 1, height: 1, width: 1, source: 'freshcaller' }
    item = nil
    widget = WidgetValidation.new(controller_params, item, true)
    widget.valid?(:create)
    error = widget.errors.full_messages
    assert error.include?('Widget type not_included')
  ensure
    Account.unstub(:current)
  end

  def test_freshcaller_availability_without_omni_dashboard_feature
    Account.stubs(:current).returns(Account.first)
    controller_params = { widget_type: WIDGET_MODULE_TOKEN_BY_NAME['ms_availability'], name: 'scorecard1', config_data: {}, x: 1, y: 1, height: 1, width: 1, source: 'freshcaller' }
    item = nil
    widget = WidgetValidation.new(controller_params, item, true)
    widget.valid?(:create)
    error = widget.errors.full_messages
    assert error.include?('Widget type not_included')
  ensure
    Account.unstub(:current)
  end

  def test_freshcaller_sla_trend_without_omni_dashboard_feature
    Account.stubs(:current).returns(Account.first)
    controller_params = { widget_type: WIDGET_MODULE_TOKEN_BY_NAME['ms_sla_trend'], name: 'scorecard1', config_data: {}, x: 1, y: 1, height: 1, width: 1, source: 'freshcaller' }
    item = nil
    widget = WidgetValidation.new(controller_params, item, true)
    widget.valid?(:create)
    error = widget.errors.full_messages
    assert error.include?('Widget type not_included')
  ensure
    Account.unstub(:current)
  end

  def test_freshcaller_time_trend_without_omni_dashboard_feature
    Account.stubs(:current).returns(Account.first)
    controller_params = { widget_type: WIDGET_MODULE_TOKEN_BY_NAME['ms_time_trend'], name: 'scorecard1', config_data: {}, x: 1, y: 1, height: 1, width: 1, source: 'freshcaller' }
    item = nil
    widget = WidgetValidation.new(controller_params, item, true)
    widget.valid?(:create)
    error = widget.errors.full_messages
    assert error.include?('Widget type not_included')
  ensure
    Account.unstub(:current)
  end

  def test_freshcaller_call_trend_with_omni_dashboard_feature
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:omni_channel_team_dashboard_enabled?).returns(true)
    controller_params = { widget_type: WIDGET_MODULE_TOKEN_BY_NAME['ms_call_trend'], name: 'scorecard1', config_data: {}, x: 1, y: 1, height: 1, width: 1, source: 'freshcaller' }
    item = nil
    widget = WidgetValidation.new(controller_params, item, true)
    widget.valid?(:create)
    error = widget.errors.full_messages
    assert_equal [], error
  ensure
    Account.any_instance.unstub(:omni_channel_team_dashboard_enabled?)
    Account.unstub(:current)
  end

  def test_freshcaller_availability_with_omni_dashboard_feature
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:omni_channel_team_dashboard_enabled?).returns(true)
    controller_params = { widget_type: WIDGET_MODULE_TOKEN_BY_NAME['ms_availability'], name: 'scorecard1', config_data: {}, x: 1, y: 1, height: 1, width: 1, source: 'freshcaller' }
    item = nil
    widget = WidgetValidation.new(controller_params, item, true)
    widget.valid?(:create)
    error = widget.errors.full_messages
    assert_equal [], error
  ensure
    Account.any_instance.unstub(:omni_channel_team_dashboard_enabled?)
    Account.unstub(:current)
  end

  def test_freshcaller_sla_trend_with_omni_dashboard_feature
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:omni_channel_team_dashboard_enabled?).returns(true)
    controller_params = { widget_type: WIDGET_MODULE_TOKEN_BY_NAME['ms_sla_trend'], name: 'scorecard1', config_data: {}, x: 1, y: 1, height: 1, width: 1, source: 'freshcaller' }
    item = nil
    widget = WidgetValidation.new(controller_params, item, true)
    widget.valid?(:create)
    error = widget.errors.full_messages
    assert_equal [], error
  ensure
    Account.any_instance.unstub(:omni_channel_team_dashboard_enabled?)
    Account.unstub(:current)
  end

  def test_freshcaller_time_trend_with_omni_dashboard_feature
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:omni_channel_team_dashboard_enabled?).returns(true)
    controller_params = { widget_type: WIDGET_MODULE_TOKEN_BY_NAME['ms_time_trend'], name: 'scorecard1', config_data: {}, x: 1, y: 1, height: 1, width: 1, source: 'freshcaller' }
    item = nil
    widget = WidgetValidation.new(controller_params, item, true)
    widget.valid?(:create)
    error = widget.errors.full_messages
    assert_equal [], error
  ensure
    Account.any_instance.unstub(:omni_channel_team_dashboard_enabled?)
    Account.unstub(:current)
  end

  def test_update_freshdesk_scorecard_without_omni_dashboard_feature_without_source
    Account.stubs(:current).returns(Account.first)
    controller_params = { id: 10, widget_type: WIDGET_MODULE_TOKEN_BY_NAME['scorecard'], name: 'scorecard1', config_data: {}, x: 1, y: 1, height: 1, width: 1 }
    item = nil
    widget = WidgetValidation.new(controller_params, item, true)
    widget.valid?(:update)
    error = widget.errors.full_messages
    assert_equal [], error
  ensure
    Account.unstub(:current)
  end

  def test_update_freshcaller_call_trend_without_omni_dashboard_feature
    Account.stubs(:current).returns(Account.first)
    controller_params = { id: 10, widget_type: WIDGET_MODULE_TOKEN_BY_NAME['ms_call_trend'], name: 'scorecard1', config_data: {}, x: 1, y: 1, height: 1, width: 1, source: 'freshcaller' }
    item = nil
    widget = WidgetValidation.new(controller_params, item, true)
    widget.valid?(:update)
    error = widget.errors.full_messages
    assert error.include?('Widget type not_included')
  ensure
    Account.unstub(:current)
  end

  def test_update_freshcaller_call_trend_with_omni_dashboard_feature
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:omni_channel_team_dashboard_enabled?).returns(true)
    controller_params = { id: 10, widget_type: WIDGET_MODULE_TOKEN_BY_NAME['ms_call_trend'], name: 'scorecard1', config_data: {}, x: 1, y: 1, height: 1, width: 1, source: 'freshcaller' }
    item = nil
    widget = WidgetValidation.new(controller_params, item, true)
    widget.valid?(:update)
    error = widget.errors.full_messages
    assert_equal [], error
  ensure
    Account.any_instance.unstub(:omni_channel_team_dashboard_enabled?)
    Account.unstub(:current)
  end
end
