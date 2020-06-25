require_relative '../../../test_helper'
require 'sidekiq/testing'

require Rails.root.join('test', 'api', 'helpers', 'automations_test_helper.rb')
module Ember
  module Admin
    class AdvancedTicketingControllerTest < ActionController::TestCase
      include AdvancedTicketingTestHelper
      include Redis::RedisKeys
      include Redis::HashMethods
      include Redis::OthersRedis
      include ::Admin::AdvancedTicketing::FieldServiceManagement::Constant
      include ::Admin::AdvancedTicketing::FieldServiceManagement::Util
      include TicketFieldsTestHelper
      include AutomationsHelper

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

      def destroy_fsm_fields_and_section
        fsm_custom_field_to_reserve.each do |field|
          Account.current.ticket_fields.find_by_name(field[:name] + "_#{Account.current.id}").try(:destroy)
        end
        Account.current.sections.find_by_label(SERVICE_TASK_SECTION).try(:destroy)
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

      def test_create_assets
        Account.stubs(:current).returns(Account.first)
        enable_assets do
          post :create, construct_params({version: 'private'}, {name: 'assets'})
          assert_response 204
          assert Account.current.assets_enabled?
        end
      ensure
        Account.unstub(:current)
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
          post :create, construct_params({ version: 'private' }, name: 'parent_child_tickets')
          assert_response 204
          assert Account.current.parent_child_tickets_enabled?
          assert_equal 0, Account.current.installed_applications.with_name('parent_child_tickets').count
          Account.any_instance.unstub(:disable_old_ui_enabled?)
        end
      end

      def test_create_fsm
        enable_fsm do
          begin
            Account.any_instance.stubs(:disable_old_ui_enabled?).returns(true)
            fields_count_before_installation = Account.current.ticket_fields.size
            total_fsm_fields_count = fsm_custom_field_to_reserve.size
            Sidekiq::Testing.inline! do
              post :create, construct_params({ version: 'private' }, name: 'field_service_management')
            end
            assert_response 204
            assert Account.current.field_service_management_enabled?
            dashboard = Account.current.dashboards.where(name: I18n.t('fsm_dashboard.name'))
            fields_count_after_installation = Account.current.ticket_fields.size
            assert fields_count_after_installation == (total_fsm_fields_count + fields_count_before_installation)
            assert dashboard.present?
            widgets = dashboard.first.widgets
            assert_equal widgets.count, FSM_WIDGETS_COUNT
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
            assert_not_nil Account.current.ticket_fields.find { |x| x.name == "cf_fsm_customer_signature_#{Account.current.id}" }
            assert Account.current.roles.map(&:name).include?(I18n.t('fsm_scheduling_dashboard.name'))
          ensure
            destroy_fsm_fields_and_section
            Account.any_instance.unstub(:disable_old_ui_enabled?)
            destroy_fsm_dashboard_and_filters
          end
        end
      end

      def test_create_fsm_with_field_tech_role
        enable_fsm do
          begin
            Sidekiq::Testing.inline! do
              post :create, construct_params({ version: 'private' }, name: 'field_service_management')
            end
            assert_response 204
            assert Account.current.field_service_management_enabled?
            assert Account.current.roles.map(&:name).include?(Helpdesk::Roles::FIELD_TECHNICIAN_ROLE[:name])
          ensure
            Account.current.rollback(:field_tech_role)
          end
        end
      end

      def test_destroy_fsm_without_any_data_loss
        enable_fsm do
          begin
            Account.current.all_service_task_dispatcher_rules.destroy_all
            Account.current.all_service_task_observer_rules.destroy_all
            Account.any_instance.stubs(:disable_old_ui_enabled?).returns(true)
            Account.any_instance.stubs(:automation_revamp_enabled?).returns(true)
            Sidekiq::Testing.inline! do
              post :create, construct_params({ version: 'private' }, name: 'field_service_management')
              assert_response 204
              assert Account.current.field_service_management_enabled?

              fields_count_after_installation = Account.current.ticket_fields.size
              service_task_dispatcher = create_dispatchr_rule(rule_type: VAConfig::SERVICE_TASK_DISPATCHER_RULE)
              assert service_task_dispatcher.present?
              assert_equal true, Account.current.all_service_task_dispatcher_rules.all?(&:active)
              service_task_observer = create_observer_rule(rule_type: VAConfig::SERVICE_TASK_OBSERVER_RULE)
              assert service_task_observer.present?
              assert_equal true, Account.current.all_service_task_observer_rules.all?(&:active)
              delete :destroy, controller_params(version: 'private', id: 'field_service_management')
              fields_count_after_destroy = Account.current.ticket_fields.size
              assert_equal true, Account.current.picklist_values.find_by_value(SERVICE_TASK_TYPE).present?
              assert_equal true, Account.current.sections.find_by_label(SERVICE_TASK_SECTION).present?
              assert fields_count_after_destroy == fields_count_after_installation - 1
              assert_blank Account.current.ticket_fields.where(name: CUSTOMER_SIGNATURE + "_#{Account.current.id}")
              assert_equal true, Account.current.all_service_task_dispatcher_rules.none?(&:active)
              assert_equal true, Account.current.all_service_task_observer_rules.none?(&:active)
            end
          ensure
            Account.any_instance.unstub(:automation_revamp_enabled?)
            Account.any_instance.unstub(:disable_old_ui_enabled?)
          end
        end
      end

      def test_reenable_fsm_without_any_data_loss
        enable_fsm do
          begin
            Account.any_instance.stubs(:disable_old_ui_enabled?).returns(true)
            Account.current.revoke_feature(:field_service_management)
            Sidekiq::Testing.inline! do
              post :create, construct_params({ version: 'private' }, name: 'field_service_management')
              assert_response 204
              assert Account.current.field_service_management_enabled?

              delete :destroy, controller_params(version: 'private', id: 'field_service_management')
              assert_equal false, Account.current.field_service_management_enabled?

              post :create, construct_params({ version: 'private' }, name: 'field_service_management')
              assert_response 204
              Account.reset_current_account
              Account.stubs(:current).returns(Account.first)
              assert Account.current.field_service_management_enabled?
              assert_equal true, Account.current.picklist_values.find_by_value(SERVICE_TASK_TYPE).present?
              assert_equal true, Account.current.sections.find_by_label(SERVICE_TASK_SECTION).present?
              assert Account.current.sections.find_by_label(SERVICE_TASK_SECTION).section_fields.size == fsm_custom_field_to_reserve.size
            end
          ensure
            Account.any_instance.unstub(:disable_old_ui_enabled?)
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
              fields_count_after_installation = Account.current.ticket_fields.size
              total_fsm_fields_count = fsm_custom_field_to_reserve.size
              Account.current.subscription.update_attributes(additional_info: { field_agent_limit: 10 })
              Account.current.subscription.addons = Subscription::Addon.where(name: Subscription::Addon::FSM_ADDON)
              Account.current.subscription.save
              Billing::Subscription.any_instance.stubs(:update_subscription).returns(true)
              delete :destroy, controller_params(version: 'private', id: 'field_service_management')
              assert_response 204
              fields_count_after_destroy = Account.current.ticket_fields.size
              assert_equal fields_count_after_destroy, (fields_count_after_installation - 1)
              assert Account.current.subscription.reload.additional_info[:field_agent_limit].present? == false
              assert Account.current.subscription.addons.count.zero?
            end
          ensure
            User.any_instance.unstub(:privilege?)
            User.unstub(:current)
            Billing::Subscription.any_instance.unstub(:update_subscription)
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

      def test_reenable_fsm_without_any_data_loss_when_fsm_field_is_deleted
        enable_fsm do
          begin
            Account.any_instance.stubs(:disable_old_ui_enabled?).returns(true)
            Sidekiq::Testing.inline! do
              post :create, construct_params({ version: 'private' }, name: 'field_service_management')
              assert_response 204
              assert Account.current.field_service_management_enabled?

              delete :destroy, controller_params(version: 'private', id: 'field_service_management')
              assert_equal false, Account.current.field_service_management_enabled?

              Account.current.ticket_fields.find_by_name(fsm_custom_field_to_reserve.first[:name] + "_#{Account.current.id}").destroy
              Account.reset_current_account
              Account.stubs(:current).returns(Account.first)
              post :create, construct_params({ version: 'private' }, name: 'field_service_management')
              assert_response 204
              assert Account.current.field_service_management_enabled?
              assert_equal true, Account.current.ticket_fields.find_by_name(fsm_custom_field_to_reserve.first[:name] + "_#{Account.current.id}").present?
            end
          ensure
            Account.any_instance.unstub(:disable_old_ui_enabled?)
          end
        end
      end

      def test_reenable_fsm_without_any_data_loss_when_fsm_fields_are_archived
        enable_fsm do
          begin
            Account.any_instance.stubs(:disable_old_ui_enabled?).returns(true)
            Account.current.launch :archive_ticket_fields
            Sidekiq::Testing.inline! do
              post :create, construct_params({ version: 'private' }, name: 'field_service_management')
              assert_response 204
              assert Account.current.field_service_management_enabled?
              delete :destroy, controller_params(version: 'private', id: 'field_service_management')
              assert_equal false, Account.current.field_service_management_enabled?
              fsm_fields = Account.current.ticket_fields_only.where(name: FSM_DEFAULT_TICKET_FIELDS.map { |tf| tf[:name] + "_#{Account.current.id}" })
              fsm_fields.each do |field|
                field.deleted = true
                field.save!
              end
              assert_empty Account.current.ticket_fields_only.where(name: FSM_DEFAULT_TICKET_FIELDS.map { |tf| tf[:name] + "_#{Account.current.id}" })
              post :create, construct_params({ version: 'private' }, name: 'field_service_management')
              assert_response 204
              assert Account.current.field_service_management_enabled?
              fsm_fields = Account.current.ticket_fields_only.where(name: FSM_DEFAULT_TICKET_FIELDS.map { |tf| tf[:name] + "_#{Account.current.id}" })
              assert_equal FSM_DEFAULT_TICKET_FIELDS.size, fsm_fields.size
            end
          ensure
            Account.any_instance.unstub(:disable_old_ui_enabled?)
            Account.current.rollback :archive_ticket_fields
          end
        end
      end

      def test_reenable_fsm_without_any_data_loss_when_fsm_section_is_deleted
        enable_fsm do
          begin
            Account.any_instance.stubs(:disable_old_ui_enabled?).returns(true)
            Sidekiq::Testing.inline! do
              post :create, construct_params({ version: 'private' }, name: 'field_service_management')
              assert_response 204
              assert Account.current.field_service_management_enabled?

              delete :destroy, controller_params(version: 'private', id: 'field_service_management')
              assert_equal false, Account.current.field_service_management_enabled?

              destroy_fsm_fields_and_section

              Account.reset_current_account
              Account.stubs(:current).returns(Account.first)
              post :create, construct_params({ version: 'private' }, name: 'field_service_management')
              assert_response 204
              assert Account.current.field_service_management_enabled?
              assert_equal true, Account.current.sections.find_by_label(SERVICE_TASK_SECTION).present?
              assert Account.current.sections.find_by_label(SERVICE_TASK_SECTION).section_fields.size == fsm_custom_field_to_reserve.size
            end
          ensure
            Account.any_instance.unstub(:disable_old_ui_enabled?)
          end
        end
      end

      def test_reenable_fsm_without_any_data_loss_when_service_task_type_is_deleted
        enable_fsm do
          begin
            Account.any_instance.stubs(:disable_old_ui_enabled?).returns(true)
            Sidekiq::Testing.inline! do
              post :create, construct_params({ version: 'private' }, name: 'field_service_management')
              assert_response 204
              assert Account.current.field_service_management_enabled?

              delete :destroy, controller_params(version: 'private', id: 'field_service_management')
              assert_equal false, Account.current.field_service_management_enabled?

              destroy_fsm_fields_and_section
              Account.current.picklist_values.find_by_value(SERVICE_TASK_TYPE).destroy

              Account.reset_current_account
              Account.stubs(:current).returns(Account.first)
              post :create, construct_params({ version: 'private' }, name: 'field_service_management')
              assert_response 204
              assert Account.current.field_service_management_enabled?
              assert_equal true, Account.current.picklist_values.find_by_value(SERVICE_TASK_TYPE).present?
              assert_equal true, Account.current.sections.find_by_label(SERVICE_TASK_SECTION).present?
              assert Account.current.sections.find_by_label(SERVICE_TASK_SECTION).section_fields.size == fsm_custom_field_to_reserve.size
            end
          ensure
            Account.any_instance.unstub(:disable_old_ui_enabled?)
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

      def test_create_fsm_with_ticket_limit_increase
        enable_fsm do
          begin
            destroy_fsm_fields_and_section
            Account.any_instance.stubs(:ticket_field_limit_increase_enabled?).returns(true)
            Sidekiq::Testing.inline! do
              post :create, construct_params({ version: 'private' }, name: 'field_service_management')
            end

            assert_response 204
            assert Account.current.field_service_management_enabled?
            assert Account.current.sections.find_by_label(SERVICE_TASK_SECTION).present?
            assert Account.current.sections.find_by_label(SERVICE_TASK_SECTION).section_fields.size == fsm_custom_field_to_reserve.size
          ensure
            destroy_fsm_fields_and_section
            Account.any_instance.unstub(:ticket_field_limit_increase_enabled?)
          end
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

      def test_destroy_assets
        Account.stubs(:current).returns(Account.first)
        enable_assets do
          post :create, construct_params({ version: 'private' }, name: 'assets')
          assert_response 204
          assert Account.current.assets_enabled?

          delete :destroy, controller_params(version: 'private', id: 'assets')
          assert_response 204
          assert_equal false, Account.current.assets_enabled?
        end
      ensure
        Account.unstub(:current)
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

      def test_fsm_enable_failure
        Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
        AdvancedTicketingControllerTest.any_instance.stubs(:create_service_task_field_type).raises(RuntimeError)
        Helpdesk::PicklistValue.any_instance.stubs(:find_by_value).returns(nil)
        Ember::Admin::AdvancedTicketingControllerTest.any_instance.expects(:notify_fsm_dev).once
        perform_fsm_operations
      ensure
        AdvancedTicketingControllerTest.any_instance.unstub(:create_service_task_field_type)
        Account.any_instance.unstub(:field_service_management_enabled?)
        Helpdesk::PicklistValue.any_instance.unstub(:find_by_value)
      end

      def test_fsm_disable_failure
        Subscription.any_instance.stubs(:addons).returns([Subscription::Addon.new])
        Subscription::Addon.any_instance.stubs(:name).returns(Subscription::Addon::FSM_ADDON)
        Subscription.any_instance.stubs(:field_agent_limit).returns(1)
        Billing::Subscription.any_instance.stubs(:update_subscription).raises(RuntimeError)
        Ember::Admin::AdvancedTicketingControllerTest.any_instance.expects(:notify_fsm_dev).once
        cleanup_fsm
      ensure
        Billing::Subscription.any_instance.unstub(:update_subscription)
        Subscription::Addon.any_instance.unstub(:name)
        Subscription.any_instance.unstub(:addons)
        Subscription.any_instance.unstub(:field_agent_limit)
      end

      def test_fsm_artifacts_with_8_date_fields
        Account.current.revoke_feature(:field_service_management)
        Account.current.custom_date_time_fields_from_cache.each(&:destroy)
        ((Account.current.custom_date_fields_from_cache.count + 1)..8).each do |i|
          create_custom_field('date_time' + i.to_s, 'date')
        end
        post :create, construct_params({ version: 'private' }, name: 'field_service_management')
        assert_response 204
      ensure
        Account.current.custom_date_fields_from_cache.each(&:destroy)
        Account.current.custom_date_time_fields_from_cache.each(&:destroy)
      end

      def test_fsm_artifacts_with_9_date_fields
        Account.current.revoke_feature(:field_service_management)
        Account.current.custom_date_time_fields_from_cache.each(&:destroy)
        ((Account.current.custom_date_fields_from_cache.count + 1)..9).each do |i|
          create_custom_field('date_time' + i.to_s, 'date')
        end
        post :create, construct_params({ version: 'private' }, name: 'field_service_management')
        assert_response 400
      ensure
        Account.current.custom_date_fields_from_cache.each(&:destroy)
        Account.current.custom_date_time_fields_from_cache.each(&:destroy)
      end

      def test_fsm_artifacts_with_10_date_fields_with_fsm_enabled
        Account.current.custom_date_time_fields_from_cache.each(&:destroy)
        perform_fsm_operations
        Account.current.revoke_feature(:field_service_management)
        ((Account.current.custom_date_fields_from_cache.count + Account.current.custom_date_time_fields_from_cache.count + 1)..10).each do |i|
          create_custom_field('date_time_' + i.to_s, 'date')
        end
        post :create, construct_params({ version: 'private' }, name: 'field_service_management')
        assert_response 204
      ensure
        Account.current.custom_date_fields_from_cache.each(&:destroy)
        Account.current.custom_date_time_fields_from_cache.each(&:destroy)
      end

      def test_fsm_text_fields_with_normalized_flexi_field_with_limit_reached
        Account.any_instance.stubs(:denormalized_flexifields_enabled?).returns(false)
        (1..2).each do |i|
          create_custom_field('text' + i.to_s, 'text')
        end
        stub_const(Helpdesk::Ticketfields::Constants, 'MAX_ALLOWED_COUNT', string: 4, text: 10, number: 20, date: 10, boolean: 10, decimal: 10) do
          stub_const(Helpdesk::Ticketfields::Constants, 'TICKET_FIELD_DATA_COUNT', string: 4, text: 10, number: 20, date: 10, boolean: 10, decimal: 10) do
            post :create, construct_params({ version: 'private' }, name: 'field_service_management')
          end
        end
        assert_response 400
      ensure
        Account.any_instance.unstub(:denormalized_flexifields_enabled?)
      end

      def test_fsm_text_fields_with_denormalized_flexi_field_with_limit_reached
        Account.any_instance.stubs(:denormalized_flexifields_enabled?).returns(true)
        (1..2).each do |i|
          create_custom_field('text' + i.to_s, 'text')
        end
        stub_const(Helpdesk::Ticketfields::Constants, 'MAX_ALLOWED_COUNT_DN', string: 4, text: 10, number: 20, date: 10, boolean: 10, decimal: 10) do
          post :create, construct_params({ version: 'private' }, name: 'field_service_management')
          assert_response 400
        end
      ensure
        Account.any_instance.unstub(:denormalized_flexifields_enabled?)
      end

      def test_service_task_fields_recreated_with_proper_options
        enable_fsm do
          begin
            perform_fsm_operations
            section = Account.current.sections.find_by_label(SERVICE_TASK_SECTION)
            section.destroy
            field = Account.current.ticket_fields.find_by_name("cf_fsm_contact_name_#{Account.current.id}")
            field.field_options.clear
            field.save!
            Account.reset_current_account
            Account.stubs(:current).returns(Account.first)
            Sidekiq::Testing.inline! do
              post :create, construct_params({ version: 'private' }, name: 'field_service_management')
            end
            assert_response 204
            section = Account.current.sections.find_by_label(SERVICE_TASK_SECTION)
            field = Account.current.ticket_fields.find_by_name("cf_fsm_contact_name_#{Account.current.id}")
            assert_not_nil section
            assert_not_nil field
            assert field.field_options[:section]
            assert field.field_options[:fsm]
          ensure
            destroy_fsm_fields_and_section
          end
        end
      end

      def test_service_task_section_on_fsm_disable_with_section_limit
        enable_fsm do
          begin
            dd_field1 = create_custom_field_dropdown_with_sections('dropdown_1', %w[AA BB])
            section1 = construct_section('section_custom_dropdown_limit1', dd_field1.id)
            dd_field2 = create_custom_field_dropdown_with_sections('dropdown_2', %w[XX YY])
            section2 = construct_section('section_custom_dropdown_limit2', dd_field2.id)
            assert_equal Helpdesk::TicketField::SECTION_LIMIT, Account.current.sections.count
            Sidekiq::Testing.inline! do
              post :create, construct_params({ version: 'private' }, name: 'field_service_management')
              assert_response 204
              assert Account.current.field_service_management_enabled?
              assert_equal Helpdesk::TicketField::FSM_SECTION_LIMIT, Account.current.sections.count

              delete :destroy, controller_params(version: 'private', id: 'field_service_management')
              Account.reset_current_account
              Account.stubs(:current).returns(Account.first)
              assert_equal false, Account.current.field_service_management_enabled?
              assert_equal Helpdesk::TicketField::FSM_SECTION_LIMIT, Account.current.sections.count
              assert_equal Helpdesk::TicketField::FSM_SECTION_LIMIT, Account.current.section_parent_fields.count
            end
          ensure
            dd_field1.try(:destroy)
            section1.try(:destroy)
            dd_field2.try(:destroy)
            section2.try(:destroy)
            destroy_fsm_fields_and_section
          end
        end
      end

      def test_revoke_geolocation_when_fsm_disabled
        Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
        Account.current.add_feature(:field_service_geolocation)
        assert_equal Account.current.has_feature?(:field_service_geolocation), true
        cleanup_fsm
        assert_equal Account.current.has_feature?(:field_service_geolocation), false
      ensure
        Account.any_instance.unstub(:field_service_management_enabled?)
      end
    end
  end
end
