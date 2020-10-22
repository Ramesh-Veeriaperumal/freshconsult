require_relative '../../../test_helper'

module Settings::Helpdesk
  class FieldServiceControllerTest < ActionController::TestCase
    include PrivilegesHelper
    include FieldServiceManagementHelper

    def wrap_cname(params = {})
      { field_service: params }
    end

    def test_update_settings
      Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
      Account.current.launch(:launch_fsm_geolocation)
      add_privilege(User.current, :admin_tasks) unless User.current.privilege?(:admin_tasks)
      params = all_settings_params_with_default_values
      params = params.each { |key, value| params[key] = !value }
      put :update_settings, construct_params({}, params)
      params.map { |key, value| [key.to_sym, value] }
      match_json(params)
      assert_response 200
      params = all_settings_params_with_default_values
      put :update_settings, construct_params({}, params)
      match_json(params)
      assert_response 200
    ensure
      Account.any_instance.unstub(:field_service_management_enabled?)
      Account.current.rollback(:launch_fsm_geolocation)
    end

    def test_rename_and_update_account_additional_setting_hash_key_as_field_service
      Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
      add_privilege(User.current, :admin_tasks) unless User.current.privilege?(:admin_tasks)
      Account.current.account_additional_settings.additional_settings.delete(:field_service)
      Account.current.account_additional_settings.additional_settings[:field_service_management] = {}
      Account.current.account_additional_settings.save!
      params = { field_agents_can_manage_appointments: true }
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
      params = all_settings_params_with_default_values
      put :update_settings, construct_params({}, params)
      match_json(request_error_pattern(:require_fsm_feature))
      assert_response 403
    ensure
      Account.any_instance.unstub(:field_service_management_enabled?)
    end

    def test_update_settings_when_fsm_toggle_disabled
      Account.any_instance.stubs(:field_service_management_toggle_enabled?).returns(false)
      add_privilege(User.current, :admin_tasks) unless User.current.privilege?(:admin_tasks)
      params = all_settings_params_with_default_values
      put :update_settings, construct_params({}, params)
      match_json(request_error_pattern(:require_feature, feature: 'field_service_management'.titleize))
      assert_response 403
    ensure
      Account.any_instance.unstub(:field_service_management_enabled?)
    end

    def test_delete_key_from_additional_settings_hash_for_default_value
      Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
      add_privilege(User.current, :admin_tasks) unless User.current.privilege?(:admin_tasks)
      setting = FSM_ADDITIONAL_SETTINGS_DEFAULT_VALUES.keys.sample
      params = { setting => !FSM_ADDITIONAL_SETTINGS_DEFAULT_VALUES[setting] }
      put :update_settings, construct_params({}, params)
      assert_equal true, Account.current.account_additional_settings.additional_settings[:field_service].key?(setting)
      params = { setting => FSM_ADDITIONAL_SETTINGS_DEFAULT_VALUES[setting] }
      put :update_settings, construct_params({}, params)
      assert_equal false, Account.current.account_additional_settings.additional_settings[:field_service].key?(setting)
    end

    def test_restrict_update_for_users_without_admin_privilege
      Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
      remove_privilege(User.current, :admin_tasks) if User.current.privilege?(:admin_tasks)
      params = FSM_ADDITIONAL_SETTINGS_DEFAULT_VALUES
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
      match_json(fetch_fsm_settings)
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
      match_json(request_error_pattern(:require_fsm_feature))
      assert_response 403
    ensure
      Account.any_instance.unstub(:field_service_management_enabled?)
    end

    def test_show_settings_when_fsm_toggle_disabled
      Account.any_instance.stubs(:field_service_management_toggle_enabled?).returns(false)
      get :show_settings, construct_params({})
      match_json(request_error_pattern(:require_feature, feature: 'field_service_management'.titleize))
      assert_response 403
    ensure
      Account.any_instance.unstub(:field_service_management_toggle_enabled?)
    end

    def test_enable_geo_location
      Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
      add_privilege(User.current, :admin_tasks) unless User.current.privilege?(:admin_tasks)
      Account.current.launch(:launch_fsm_geolocation)
      Account.current.account_additional_settings.save!
      assert_equal Account.current.field_service_geolocation_enabled?, false
      params = { geo_location_enabled: true }
      put :update_settings, construct_params({}, params)
      assert_response 200
      assert Account.current.field_service_geolocation_enabled?
    ensure
      Account.current.disable_setting(:field_service_geolocation)
      Account.any_instance.unstub(:field_service_management_enabled?)
      Account.current.rollback(:launch_fsm_geolocation)
    end

    def test_disable_geo_location
      Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
      add_privilege(User.current, :admin_tasks) unless User.current.privilege?(:admin_tasks)
      Account.current.launch(:launch_fsm_geolocation)
      Account.current.enable_setting(:field_service_geolocation)
      params = { geo_location_enabled: false }
      put :update_settings, construct_params({}, params)
      assert_response 200
      assert_equal Account.current.field_service_geolocation_enabled?, false
    ensure
      Account.any_instance.unstub(:field_service_management_enabled?)
      Account.current.rollback :launch_fsm_geolocation
    end

    def test_geo_location_without_lp
      Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
      add_privilege(User.current, :admin_tasks) unless User.current.privilege?(:admin_tasks)
      Account.current.account_additional_settings.save!
      params = { geo_location_enabled: false }
      put :update_settings, construct_params({}, params)
      assert_response 403
    ensure
      Account.any_instance.unstub(:field_service_management_enabled?)
    end

    def test_enable_location_tagging
      Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
      add_privilege(User.current, :admin_tasks) unless User.current.privilege?(:admin_tasks)
      Account.current.account_additional_settings.save!
      assert_equal Account.current.location_tagging_enabled?, false
      params = { location_tagging_enabled: true }
      put :update_settings, construct_params({}, params)
      assert_response 200
      assert Account.current.location_tagging_enabled?
    ensure
      Account.current.disable_setting(:location_tagging)
      Account.any_instance.unstub(:field_service_management_enabled?)
    end

    def test_disable_location_tagging
      Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
      add_privilege(User.current, :admin_tasks) unless User.current.privilege?(:admin_tasks)
      Account.current.enable_setting(:location_tagging)
      Account.current.account_additional_settings.save!
      params = { location_tagging_enabled: false }
      put :update_settings, construct_params({}, params)
      assert_response 200
      assert_equal Account.current.location_tagging_enabled?, false
    ensure
      Account.any_instance.unstub(:field_service_management_enabled?)
    end

    def test_update_field_service_with_invalid_params
      Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
      User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(true)
      params = {}
      put :update_settings, construct_params({}, params)
      assert_response 400
      match_json(request_error_pattern(:missing_params))
      params = { field_agents_can_manage_appointments: nil }
      put :update_settings, construct_params({}, params)
      assert_response 400
      match_json([bad_request_error_pattern('field_agents_can_manage_appointments', :datatype_mismatch, expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: 'Null')])
    end

    private

      def all_settings_params_with_default_values(params = {})
        UPDATE_SETTINGS_FIELDS.each do |setting|
          params[setting] = FSM_ADDITIONAL_SETTINGS_DEFAULT_VALUES[setting] || AccountSettings::SettingsConfig[FIELD_SERVICE_PARAMS_SETTINGS_MAPPING[setting]][:default]
        end
        params
      end
  end
end
