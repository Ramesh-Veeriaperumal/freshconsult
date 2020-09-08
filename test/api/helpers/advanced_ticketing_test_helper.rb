module AdvancedTicketingTestHelper
  include ::Admin::AdvancedTicketing::FieldServiceManagement::Util

  def disable_feature(feature)
    Account.current.revoke_feature(feature)
    Account.any_instance.stubs(:disable_old_ui_enabled?).returns(false)
    yield
  ensure
    Account.current.add_feature(feature) unless Account.current.safe_send("#{feature}_enabled?")
    Account.current.installed_applications.with_name(feature).destroy_all
    Account.any_instance.unstub(:disable_old_ui_enabled?)
  end

  def enable_fsm
    Account.current.set_feature(:disable_old_ui)
    Account.current.set_feature(:field_service_management_toggle) unless Account.current.has_feature?(:field_service_management_toggle)
    yield
  ensure
    destroy_fsm_dashboard_and_filters
    cleanup_fsm
    Account.current.revoke_feature(:field_service_management)
  end

  def enable_assets
    Account.current.set_feature(:disable_old_ui)
    Account.current.set_feature(:assets_toggle) unless Account.current.has_feature?(:assets_toggle)
    yield
  ensure
    Account.current.revoke_feature(:assets_toggle)
    Account.current.revoke_feature(:assets)
  end

  def create_installed_application(app_name)
    application = Integrations::Application.available_apps(Account.current.id).find_by_name(app_name)
    Account.current.installed_applications.create({application: application})
    Account.any_instance.stubs(:disable_old_ui_enabled?).returns(false)
    yield
  ensure
    Account.current.installed_applications.find_by_application_id(application.id).try(:destroy)
    Account.current.add_feature(app_name) unless Account.current.safe_send("#{app_name}_enabled?")
    Account.any_instance.unstub(:disable_old_ui_enabled?)
  end

  def create_success_pattern(app)
    assert_response 204
    assert Account.current.safe_send("#{app}_enabled?")
    assert_equal 1, Account.current.installed_applications.with_name(app).count
  end

  def destroy_success_pattern(app)
    assert_response 204
    assert_equal false, Account.current.safe_send("#{app}_enabled?")
    assert_equal 0, Account.current.installed_applications.with_name(app).count
  end

  def metrics_hash
    {
      parent_tickets_count: 380174,
      child_tickets_count: 474104,
      tracker_tickets_count: 21326,
      related_tickets_count: 100716,
      shared_ownership_tickets_count: 53946
    }
  end

  def metrics_pattern
    {
      parent_child_tickets: {
        parent_tickets_count: metrics_hash[:parent_tickets_count],
        child_tickets_count: metrics_hash[:child_tickets_count]
      },
      link_tickets: {
        tracker_tickets_count: metrics_hash[:tracker_tickets_count],
        related_tickets_count: metrics_hash[:related_tickets_count]
      },
      shared_ownership: {
        shared_ownership_tickets_count: metrics_hash[:shared_ownership_tickets_count]
      }
    }
  end

end
