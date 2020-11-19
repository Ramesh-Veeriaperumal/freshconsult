# frozen_string_literal: true

require_relative '../../../api/test_helper'
require_relative '../../../core/helpers/controller_test_helper'
require_relative '../../../core/helpers/users_test_helper'
require_relative '../../../api/helpers/privileges_helper'
['privileges_helper.rb'].each { |file| require Rails.root.join('test', 'api', 'helpers', file) }
require 'webmock/minitest'
class Reports::ScheduledExportsControllerTest < ActionController::TestCase
  include PrivilegesHelper
  def setup
    super
    before_all
  end

  def teardown
    super
  end

  def before_all
    @account = Account.first.make_current
    @user = User.current || add_new_user(@account).make_current
  end

  def test_index_with_activity_export_feature_and_without_privilege
    Account.any_instance.stubs(:ticket_activity_export_enabled?).returns(true)
    @controller.stubs(:privilege?).with(:manage_account).returns(false)
    @controller.stubs(:privilege?).with(:admin_tasks).returns(false)
    Account.any_instance.stubs(:auto_ticket_export_enabled?).returns(false)
    get :index
    assert_response 302
    assert_includes response.redirect_url, support_login_url
  ensure
    @controller.unstub(:privilege?)
    Account.any_instance.unstub(:ticket_activity_export_enabled?)
    Account.any_instance.unstub(:auto_ticket_export_enabled?)
  end

  def test_index_with_properties_export_feature_and_without_privilege
    Account.any_instance.stubs(:ticket_activity_export_enabled?).returns(false)
    @controller.stubs(:privilege?).with(:manage_account).returns(false)
    @controller.stubs(:privilege?).with(:admin_tasks).returns(false)
    Account.any_instance.stubs(:auto_ticket_export_enabled?).returns(true)
    get :index
    assert_response 302
    assert_includes response.redirect_url, support_login_url
  ensure
    @controller.unstub(:privilege?)
    Account.any_instance.unstub(:ticket_activity_export_enabled?)
    Account.any_instance.unstub(:auto_ticket_export_enabled?)
  end

  def test_index_scheduled_export
    Account.any_instance.stubs(:ticket_activity_export_enabled?).returns(true)
    Account.any_instance.stubs(:auto_ticket_export_enabled?).returns(true)
    @controller.stubs(:privilege?).returns(true)
    get :index
    assert_response 200
  ensure
    @controller.unstub(:privilege?)
    Account.any_instance.unstub(:ticket_activity_export_enabled?)
    Account.any_instance.unstub(:auto_ticket_export_enabled?)
  end

  def test_new_properties_export_without_admin_tasks_and_with_manage_account_privilege
    Account.any_instance.stubs(:ticket_activity_export_enabled?).returns(true)
    @controller.stubs(:privilege?).with(:manage_account).returns(true)
    Account.any_instance.stubs(:auto_ticket_export_enabled?).returns(true)
    @controller.stubs(:privilege?).with(:admin_tasks).returns(false)
    get :new
    assert_response 302
    assert_includes response.redirect_url, support_login_url
  ensure
    @controller.unstub(:privilege?)
    Account.any_instance.unstub(:ticket_activity_export_enabled?)
    Account.any_instance.unstub(:auto_ticket_export_enabled?)
  end

  def test_new_properties_scheduled_export
    Account.any_instance.stubs(:ticket_activity_export_enabled?).returns(true)
    Account.any_instance.stubs(:auto_ticket_export_enabled?).returns(true)
    @controller.stubs(:privilege?).returns(true)
    get :new
    assert_response 200
  ensure
    @controller.unstub(:privilege?)
    Account.any_instance.unstub(:ticket_activity_export_enabled?)
    Account.any_instance.unstub(:auto_ticket_export_enabled?)
  end

  def test_edit_activity_export_without_manage_account_privilege_and_with_admin_tasks_privilege
    Account.any_instance.stubs(:ticket_activity_export_enabled?).returns(true)
    @controller.stubs(:privilege?).with(:manage_account).returns(false)
    Account.any_instance.stubs(:auto_ticket_export_enabled?).returns(true)
    @controller.stubs(:privilege?).with(:admin_tasks).returns(true)
    get :edit_activity
    assert_response 302
    assert_includes response.redirect_url, support_login_url
  ensure
    @controller.unstub(:privilege?)
    Account.any_instance.unstub(:ticket_activity_export_enabled?)
    Account.any_instance.unstub(:auto_ticket_export_enabled?)
  end

  def test_edit_activity_scheduled_export
    Account.any_instance.stubs(:ticket_activity_export_enabled?).returns(true)
    Account.any_instance.stubs(:auto_ticket_export_enabled?).returns(true)
    @controller.stubs(:privilege?).returns(true)
    get :edit_activity
    assert_response 200
  ensure
    @controller.unstub(:privilege?)
    Account.any_instance.unstub(:ticket_activity_export_enabled?)
    Account.any_instance.unstub(:auto_ticket_export_enabled?)
  end
end
