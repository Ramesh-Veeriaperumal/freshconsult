require_relative '../unit_test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
class SchedulerExportCleanupPollerTest < ActionView::TestCase
  include AccountTestHelper
  def teardown
    Account.unstub(:current)
    super
  end

  def test_scheduler_contact_export_cleanup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @user = create_test_account
    @export = @account.data_exports.new(source: DataExport::EXPORT_TYPE['contact'.to_sym],
                                        user: @user,
                                        status: DataExport::EXPORT_STATUS[:completed])
    @export.save
    args = { 'account_id' => @account.id, 'export_id' => @export.id,
             'enqueued_at' => 1516266671, 'scheduler_type' => 'export_cleanup' }
    response = Export::SchedulerExportCleanupPoller.new.perform(nil, args)
    assert_equal response, true
    export_data = @account.data_exports.reload.where(id: @export.id).first
    assert_equal export_data, nil
  end

  def test_scheduler_company_export_cleanup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @user = create_test_account
    @export = @account.data_exports.new(source: DataExport::EXPORT_TYPE['company'.to_sym],
                                        user: @user,
                                        status: DataExport::EXPORT_STATUS[:completed])
    @export.save
    args = { 'account_id' => @account.id, 'export_id' => @export.id,
             'enqueued_at' => 1516266671, 'scheduler_type' => 'export_cleanup' }
    response = Export::SchedulerExportCleanupPoller.new.perform(nil, args)
    assert_equal response, true
    export_data = @account.data_exports.reload.where(id: @export.id).first
    assert_equal export_data, nil
  end

  def test_scheduler_ticket_export_cleanup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @user = create_test_account
    @export = @account.data_exports.new(source: DataExport::EXPORT_TYPE['ticket'.to_sym],
                                        user: @user,
                                        status: DataExport::EXPORT_STATUS[:completed])
    @export.save
    args = { 'account_id' => @account.id, 'export_id' => @export.id,
             'enqueued_at' => 1516266671, 'scheduler_type' => 'export_cleanup' }
    response = Export::SchedulerExportCleanupPoller.new.perform(nil, args)
    assert_equal response, true
    export_data = @account.data_exports.reload.where(id: @export.id).first
    assert_equal export_data, nil
  end

  def test_scheduler_archive_ticket_export_cleanup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @user = create_test_account
    @export = @account.data_exports.new(source: DataExport::EXPORT_TYPE['archive_ticket'.to_sym],
                                        user: @user,
                                        status: DataExport::EXPORT_STATUS[:completed])
    @export.save
    args = { 'account_id' => @account.id, 'export_id' => @export.id,
             'enqueued_at' => 1516266671, 'scheduler_type' => 'export_cleanup' }
    response = Export::SchedulerExportCleanupPoller.new.perform(nil, args)
    assert_equal response, true
    export_data = @account.data_exports.reload.where(id: @export.id).first
    assert_equal export_data, nil
  end
end
