require_relative '../test_helper'

class FieldServiceManagementControllerTest < ActionController::TestCase
  include PrivilegesHelper
  include FieldServiceManagementHelper

  def wrap_cname(params = {})
    { field_service_management: params }
  end

  def test_update_settings
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
    add_privilege(User.current, :admin_tasks) unless User.current.privilege?(:admin_tasks)
    params = FSM_SETTINGS_DEFAULT_VALUES.dup
    params = params.each { |key, value| params[key] = !value }
    put :update_settings, construct_params({}, params)
    params.map { |key, value| [key.to_sym, value] }
    assert params == Account.current.account_additional_settings.additional_settings[:field_service]
    match_json(fetch_fsm_settings(Account.current.account_additional_settings))
    assert_response 200
    params = FSM_SETTINGS_DEFAULT_VALUES.dup
    put :update_settings, construct_params({}, params)
    assert Account.current.account_additional_settings.additional_settings[:field_service].empty?
    match_json(fetch_fsm_settings(Account.current.account_additional_settings))
    assert_response 200
  ensure
    Account.any_instance.unstub(:field_service_management_enabled?)
  end

  def test_rename_and_update_hash_key_as_field_service
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
    add_privilege(User.current, :admin_tasks) unless User.current.privilege?(:admin_tasks)
    Account.current.account_additional_settings.additional_settings.delete(:field_service)
    Account.current.account_additional_settings.additional_settings[:field_service_management] = {}
    Account.current.account_additional_settings.save!
    params = FSM_SETTINGS_DEFAULT_VALUES.dup
    put :update_settings, construct_params({}, params)
    assert_response 200
    assert Account.current.account_additional_settings.additional_settings.key?(:field_service)
    refute Account.current.account_additional_settings.additional_settings.key?(:field_service_management)
  ensure
    Account.any_instance.unstub(:field_service_management_enabled?)
  end

  def test_update_settings_when_fsm_disabled
    Account.any_instance.stubs(:field_service_management_enabled?).returns(false)
    add_privilege(User.current, :admin_tasks) unless User.current.privilege?(:admin_tasks)
    params = FSM_SETTINGS_DEFAULT_VALUES
    put :update_settings, construct_params({}, params)
    match_json(request_error_pattern(:require_feature, feature: 'field_service_management'.titleize))
    assert_response 403
  ensure
    Account.any_instance.unstub(:field_service_management_enabled?)
  end

  def test_delete_key_from_additional_settings_hash_for_default_value
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
    add_privilege(User.current, :admin_tasks) unless User.current.privilege?(:admin_tasks)
    params = { UPDATE_SETTINGS_FIELDS[0] => !FSM_SETTINGS_DEFAULT_VALUES[UPDATE_SETTINGS_FIELDS[0]] }
    put :update_settings, construct_params({}, params)
    assert_equal true, Account.current.account_additional_settings.additional_settings[:field_service].key?(UPDATE_SETTINGS_FIELDS[0].to_sym)
    params = { UPDATE_SETTINGS_FIELDS[0] => FSM_SETTINGS_DEFAULT_VALUES[UPDATE_SETTINGS_FIELDS[0]] }
    put :update_settings, construct_params({}, params)
    assert_equal false, Account.current.account_additional_settings.additional_settings[:field_service].key?(UPDATE_SETTINGS_FIELDS[0].to_sym)
  end

  def test_restrict_update_for_users_without_admin_privilege
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
    remove_privilege(User.current, :admin_tasks) if User.current.privilege?(:admin_tasks)
    params = FSM_SETTINGS_DEFAULT_VALUES
    put :update_settings, construct_params({}, params)
    match_json(request_error_pattern(:access_denied))
    assert_response 403
  ensure
    Account.any_instance.unstub(:field_service_management_enabled?)
    add_privilege(User.current, :admin_tasks) unless User.current.privilege?(:admin_tasks)
  end

  def test_show_settings
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
    add_privilege(User.current, :admin_tasks) unless User.current.privilege?(:admin_tasks)
    get :show_settings, construct_params({})
    match_json(fetch_fsm_settings(Account.current.account_additional_settings))
    assert_response 200
  ensure
    Account.any_instance.unstub(:field_service_management_enabled?)
  end

  def test_show_settings_without_admin_privilege
    Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
    remove_privilege(User.current, :admin_tasks) if User.current.privilege?(:admin_tasks)
    get :show_settings, construct_params({})
    match_json(request_error_pattern(:access_denied))
    assert_response 403
  end

  def test_show_settings_when_fsm_disabled
    Account.any_instance.stubs(:field_service_management_enabled?).returns(false)
    get :show_settings, construct_params({})
    match_json(request_error_pattern(:require_feature, feature: 'field_service_management'.titleize))
    assert_response 403
  ensure
    Account.any_instance.unstub(:field_service_management_enabled?)
  end
end
