require_relative '../../../test_helper'
require 'sidekiq/testing'

module Ember
  module Admin
    class AdvancedTicketingControllerTest < ActionController::TestCase
      include AdvancedTicketingTestHelper
      include Redis::RedisKeys
      include Redis::HashMethods
      include Redis::OthersRedis
      include ::Admin::AdvancedTicketing::FieldServiceManagement::Constant
      include ::Admin::AdvancedTicketing::FieldServiceManagement::Util

      def setup
        super
        Integrations::InstalledApplication.any_instance.stubs(:marketplace_enabled?).returns(false)
      end
      def teardown
        super
        Integrations::InstalledApplication.unstub(:marketplace_enabled?)
      end

      def wrap_cname(params)
        { advanced_ticketing: params }
      end

      def test_create_parent_child
        disable_feature(:parent_child_tickets) do
          post :create, construct_params({version: 'private'}, {name: 'parent_child_tickets'})
          create_success_pattern(:parent_child_tickets)
        end
      end

      def test_create_link_tickets
        disable_feature(:link_tickets) do
          post :create, construct_params({version: 'private'}, {name: 'link_tickets'})
          create_success_pattern(:link_tickets)
        end
      end

      def test_create_shared_ownership
        disable_feature(:shared_ownership) do
          post :create, construct_params({version: 'private'}, {name: 'shared_ownership'})
          create_success_pattern(:shared_ownership)
        end
      end

      def test_create_parent_child_without_toggle
        disable_feature(:parent_child_tickets) do
          Account.any_instance.stubs(:parent_child_tickets_toggle_enabled?).returns(false)
          post :create, construct_params({version: 'private'}, {name: 'parent_child_tickets'})
          assert_response 400
          match_json([bad_request_error_pattern('name', :require_feature, code: :invalid_value, feature: :parent_child_tickets)])
          Account.any_instance.unstub(:parent_child_tickets_toggle_enabled?)
        end
      end

      def test_create_with_additional_params
        disable_feature(:parent_child_tickets) do
          post :create, construct_params({version: 'private'}, {name: 'parent_child_tickets', test: 'parent_child_tickets'})
          assert_response 400
          match_json([bad_request_error_pattern('test', :invalid_field)])
        end
      end

      def test_create_with_invalid_params
        disable_feature(:parent_child_tickets) do
          post :create, construct_params({version: 'private'}, {name: 'abcd'})
          assert_response 400
          match_json([bad_request_error_pattern('name', :not_included, code: :invalid_value, list: AdvancedTicketingConstants::ADVANCED_TICKETING_APPS.join(','))])
        end
      end

      def test_create_with_existing_feature
        post :create, construct_params({version: 'private'}, {name: 'parent_child_tickets'})
        assert_response 400
        match_json([bad_request_error_pattern('name', :feature_exists, code: :invalid_value, feature: :parent_child_tickets)])
      end

      def test_create_with_disable_old_ui_enabled
        disable_feature(:parent_child_tickets) do
          Account.any_instance.stubs(:disable_old_ui_enabled?).returns(true)
          post :create, construct_params({version: 'private'}, {name: 'parent_child_tickets'})
          assert_response 204
          assert Account.current.parent_child_tickets_enabled?
          assert_equal 0,Account.current.installed_applications.with_name('parent_child_tickets').count
          Account.any_instance.unstub(:disable_old_ui_enabled?)
        end
      end

      def test_create_fsm
        enable_fsm do
          begin
            old_ticket_filter_count = Account.current.ticket_filters.count
            Account.any_instance.stubs(:disable_old_ui_enabled?).returns(true)
            Account.any_instance.stubs(:fsm_dashboard_enabled?).returns(true)
            fields_count_before_installation = Account.current.ticket_fields.size
            total_fsm_fields_count = CUSTOM_FIELDS_TO_RESERVE.size
            Account.current.subscription.update_attributes(additional_info: { field_agent_limit: 10 })
            Sidekiq::Testing.inline! do
              post :create, construct_params({ version: 'private' }, { name: 'field_service_management' })
            end
            assert_response 204
            assert Account.current.field_service_management_enabled?
            dashboard = Account.current.dashboards.where(name: I18n.t("fsm_dashboard.name"))
            fields_count_after_installation = Account.current.ticket_fields.size
            assert fields_count_after_installation == (total_fsm_fields_count + fields_count_before_installation)
            assert dashboard.present?
            widgets = dashboard.first.widgets
            assert_equal widgets.count, FSM_WIDGETS_COUNT
            assert Account.current.ticket_filters.count == old_ticket_filter_count + FSM_TICKET_FILTER_COUNT
            assert Account.current.subscription.additional_info[:field_agent_limit].present? == false
            pick_list_id = Account.current.ticket_types_from_cache.find { |x| x.value == SERVICE_TASK_TYPE }.id
            widget = widgets.find { |element| element.name == I18n.t('fsm_dashboard.widgets.' + SERVICE_TASKS_INCOMING_TREND_WIDGET_NAME) }
            assert_equal widget[:config_data][:ticket_type], pick_list_id
            assert_equal widget[:config_data][:metric], ::Dashboard::Custom::TicketTrendCard::METRICS_MAPPING.key('RECEIVED_TICKETS')
            widget = widgets.find { |element| element.name == I18n.t('fsm_dashboard.widgets.' + SERVICE_TASKS_RESOLUTION_TREND_WIDGET_NAME) }
            assert_equal widget[:config_data][:ticket_type], pick_list_id
            assert_equal widget[:config_data][:metric], ::Dashboard::Custom::TicketTrendCard::METRICS_MAPPING.key('RESOLVED_TICKETS')
            widget = widgets.find { |element| element.name == I18n.t('fsm_dashboard.widgets.' + SERVICE_TASKS_AVG_RESOLUTION_WIDGET_NAME) }
            assert_equal widget[:config_data][:ticket_type], pick_list_id
            assert_equal widget[:config_data][:metric], ::Dashboard::Custom::TimeTrendCard::METRICS_MAPPING.key('AVG_RESOLUTION_TIME')
          ensure
            Account.any_instance.unstub(:disable_old_ui_enabled?)
            Account.any_instance.unstub(:fsm_dashboard_enabled?)
            destroy_fsm_dashboard_and_filters
          end
        end
      end

      def test_destroy_fsm_with_lp_and_privilege
        enable_fsm do
          begin
            Sidekiq::Testing.inline! do
                post :create, construct_params({ version: 'private' }, name: 'field_service_management')
                assert_response 204
                assert Account.current.field_service_management_enabled?
                User.stubs(:current).returns(User.first)
                User.any_instance.stubs(:privilege?).with(:manage_account).returns(true)
                User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(true)
                Account.any_instance.stubs(:disable_field_service_management_enabled?).returns(true)
                fields_count_after_installation = Account.current.ticket_fields.size
                total_fsm_fields_count = CUSTOM_FIELDS_TO_RESERVE.size
                Account.current.subscription.update_attributes(additional_info: { field_agent_limit: 10 })
                Account.current.subscription.addons = Subscription::Addon.where(name: Subscription::Addon::FSM_ADDON)
                Account.current.subscription.save
                delete :destroy, controller_params(version: 'private', id: 'field_service_management')
                assert_response 204
                fields_count_after_destroy = Account.current.ticket_fields.size
                assert fields_count_after_destroy == (fields_count_after_installation - total_fsm_fields_count)
                assert Account.current.subscription.additional_info[:field_agent_limit].present? == false
                assert Account.current.subscription.addons.count.zero?
            end
          ensure
            User.any_instance.unstub(:privilege?)
            User.unstub(:current)
            Account.any_instance.unstub(:disable_field_service_management_enabled?)
          end
        end
      end

      def test_destroy_fsm_without_lp
        enable_fsm do
          begin
            Sidekiq::Testing.inline! do
                post :create, construct_params({ version: 'private' }, name: 'field_service_management')
                assert_response 204
                assert Account.current.field_service_management_enabled?
                User.stubs(:current).returns(User.first)
                User.any_instance.stubs(:privilege?).with(:manage_account).returns(true)
                User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(true)
                delete :destroy, controller_params(version: 'private', id: 'field_service_management')
                assert_response 403
                match_json(request_error_pattern(:access_denied))
            end
          ensure
            User.any_instance.unstub(:privilege?)
            User.unstub(:current)
          end
        end
      end

      def test_destroy_fsm_without_privilege
        enable_fsm do
          begin
            Sidekiq::Testing.inline! do
                post :create, construct_params({ version: 'private' }, name: 'field_service_management')
                assert_response 204
                assert Account.current.field_service_management_enabled?
                User.stubs(:current).returns(User.first)
                User.any_instance.stubs(:privilege?).with(:manage_account).returns(false)
                User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(true)
                Account.any_instance.stubs(:disable_field_service_management_enabled?).returns(true)
                delete :destroy, controller_params(version: 'private', id: 'field_service_management')
                assert_response 403
                match_json(request_error_pattern(:access_denied))
            end
          ensure
            Account.any_instance.unstub(:disable_field_service_management_enabled?)
            User.any_instance.unstub(:privilege?)
            User.unstub(:current)
          end
        end
      end

      def test_destroy_fsm_without_lp_and_privilege
        enable_fsm do
          begin
            Sidekiq::Testing.inline! do
                post :create, construct_params({ version: 'private' }, name: 'field_service_management')
                assert_response 204
                assert Account.current.field_service_management_enabled?
                User.stubs(:current).returns(User.first)
                User.any_instance.stubs(:privilege?).with(:manage_account).returns(false)
                User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(true)
                delete :destroy, controller_params(version: 'private', id: 'field_service_management')
                assert_response 403
                match_json(request_error_pattern(:access_denied))
            end
          ensure
            User.any_instance.unstub(:privilege?)
            User.unstub(:current)
          end
        end
      end

      # Test create with failed validation.
      def test_create_fsm_with_old_ui_enabled
        enable_fsm do
          Account.current.revoke_feature(:disable_old_ui)
          post :create, construct_params({version: 'private'}, {name: 'field_service_management'})

          assert_response 400
          match_json([bad_request_error_pattern('name', :fsm_only_on_mint_ui, code: :invalid_value, feature: :field_service_management)])
        end
      end

      def test_create_fsm_with_launch_party_disabled
        enable_fsm do
          Account.any_instance.stubs(:disable_old_ui_enabled?).returns(true)
          Account.current.rollback(:field_service_management_lp)
          post :create, construct_params({version: 'private'}, {name: 'field_service_management'})

          assert_response 400
          match_json([bad_request_error_pattern('name', :fsm_launch_party_not_enabled, code: :invalid_value, feature: :field_service_management)])

          Account.current.launch(:field_service_management_lp)
          Account.any_instance.unstub(:disable_old_ui_enabled?)
        end
      end

      # Feature already enabled validation.
      def test_create_fsm_with_already_enabled
        enable_fsm do
          Account.any_instance.stubs(:disable_old_ui_enabled?).returns(true)
          Account.current.set_feature(:field_service_management)
          post :create, construct_params({version: 'private'}, {name: 'field_service_management'})

          assert_response 400
          match_json([bad_request_error_pattern('name', :feature_exists, code: :invalid_value, feature: :field_service_management)])

          Account.any_instance.unstub(:disable_old_ui_enabled?)
        end
      end

      # Todo: Custom field count validation_fail

      def test_create_fsm_with_plan_based_feature_disabled
        enable_fsm do
          Account.any_instance.stubs(:disable_old_ui_enabled?).returns(true)
          Account.any_instance.stubs(:field_service_management_toggle_enabled?).returns(false)
          post :create, construct_params({version: 'private'}, {name: 'field_service_management'})
          assert_response 400
          match_json([bad_request_error_pattern('name', :require_feature, code: :invalid_value, feature: :field_service_management)])
          Account.any_instance.unstub(:field_service_management_toggle_enabled?)
          Account.any_instance.unstub(:disable_old_ui_enabled?)
        end
      end

      def test_destroy_parent_child
        Account.current.installed_applications.with_name(:parent_child_tickets).each do |inst_app|
          inst_app.destroy
        end
        create_installed_application(:parent_child_tickets) do
          delete :destroy, controller_params(version: 'private', id: 'parent_child_tickets')
          destroy_success_pattern(:parent_child_tickets)
        end
      end

      def test_destroy_link_tickets
        create_installed_application(:link_tickets) do
          delete :destroy, controller_params(version: 'private', id: 'link_tickets')
          destroy_success_pattern(:link_tickets)
        end
      end

      def test_destroy_shared_ownership
        create_installed_application(:shared_ownership) do
          delete :destroy, controller_params(version: 'private', id: 'shared_ownership')
          destroy_success_pattern(:shared_ownership)
        end
      end

      def test_destroy_with_disable_old_ui_enabled
        create_installed_application(:parent_child_tickets) do
          Account.any_instance.stubs(:disable_old_ui_enabled?).returns(true)
          delete :destroy, controller_params(version: 'private', id: 'parent_child_tickets')
          assert_response 204
          assert_equal 0,Account.current.installed_applications.with_name('parent_child_tickets').count
          assert_equal false, Account.current.parent_child_tickets_enabled?
          Account.any_instance.unstub(:disable_old_ui_enabled?)
        end
      end

      def test_destroy_with_feature_and_without_installed_app_entry
        Account.current.add_feature(:parent_child_tickets) unless Account.current.parent_child_tickets_enabled?
        Account.any_instance.stubs(:disable_old_ui_enabled?).returns(true)
        delete :destroy, controller_params(version: 'private', id: 'parent_child_tickets')
        assert_response 204
        assert_equal false, Account.current.parent_child_tickets_enabled?
      ensure
        Account.any_instance.unstub(:disable_old_ui_enabled?)
        Account.current.revoke_feature(:parent_child_tickets) if Account.current.parent_child_tickets_enabled?
      end

      def test_destroy_without_existing_feature
        create_installed_application(:parent_child_tickets) do
          Account.any_instance.stubs(:parent_child_tickets_enabled?).returns(false)
          delete :destroy, controller_params(version: 'private', id: 'parent_child_tickets')
          assert_response 400
          match_json([bad_request_error_pattern('id', :feature_unavailable, code: :invalid_value, feature: :parent_child_tickets)])
          Account.any_instance.unstub(:parent_child_tickets_enabled?)
        end
      end

      def test_destroy_with_invalid_params
        create_installed_application(:parent_child_tickets) do
          delete :destroy, controller_params(version: 'private', id: 'abcd')
          assert_response 404
        end
      end

      def test_insights_with_invalid_params
        get :insights, controller_params(version: 'private', test: 'abcd')
        assert_response 400
        match_json([bad_request_error_pattern('test', :invalid_field)])
      end

      def test_insights
        multi_set_redis_hash(ADVANCED_TICKETING_METRICS, metrics_hash.to_a.flatten)
        get :insights, controller_params(version: 'private')
        assert_response 200
        match_json(metrics_pattern)
      ensure
        remove_others_redis_key(ADVANCED_TICKETING_METRICS)
      end

      def test_insights_from_s3
        AwsWrapper::S3Object.stubs(:read).returns(metrics_hash.to_json)
        get :insights, controller_params(version: 'private')
        assert_response 200
        match_json(metrics_pattern)
        assert_equal false, multi_get_all_redis_hash(ADVANCED_TICKETING_METRICS).empty?
      ensure
        AwsWrapper::S3Object.unstub(:read)
        remove_others_redis_key(ADVANCED_TICKETING_METRICS)
      end

      def test_create_with_exception
        disable_feature(:parent_child_tickets) do
          Integrations::InstalledApplication.any_instance.stubs(:save!).raises(RuntimeError)
          post :create, construct_params({version: 'private'}, {name: 'parent_child_tickets'})
          assert_response 400
        end
      ensure
        Integrations::InstalledApplication.any_instance.unstub(:save!)
      end

      def test_destroy_with_exception
        create_installed_application(:parent_child_tickets) do
          Integrations::InstalledApplication.any_instance.stubs(:destroy).raises(RuntimeError)
          delete :destroy, controller_params(version: 'private', id: 'parent_child_tickets')
          assert_response 400
          Integrations::InstalledApplication.any_instance.unstub(:destroy)
        end
      end

      def test_insights_with_exception
        AwsWrapper::S3Object.stubs(:read).raises(RuntimeError)
        get :insights, controller_params(version: 'private')
        assert_response 500
      ensure
        AwsWrapper::S3Object.unstub(:read)
        remove_others_redis_key(ADVANCED_TICKETING_METRICS)
      end
    end
  end
end
