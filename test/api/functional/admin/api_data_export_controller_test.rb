require_relative '../../test_helper.rb'
require 'sidekiq/testing'
require 'webmock/minitest'


class Admin::ApiDataExportsControllerTest < ActionController::TestCase
  include TicketsTestHelper
  
  def test_export_user_data
    Helpdesk::ExportDataWorker.any_instance.unstub(:export_users_data)
    Sidekiq::Testing.inline! do
      post :account_export, construct_params({})
    end
    assert_response 204
    data_export = @account.data_exports.last
    assert_equal data_export.status, DataExport::EXPORT_STATUS[:completed]
    assert_equal data_export.source, DataExport::EXPORT_TYPE[:backup]
    assert_equal data_export.last_error, nil
    @account.data_exports.destroy_all
  end
  
  def test_export_user_data_when_already_triggered
    Helpdesk::ExportDataWorker.any_instance.unstub(:export_users_data)
  
    data_export_record = @account.data_exports.new(
                        :source => DataExport::EXPORT_TYPE[:backup], 
                        :user => User.current,
                        :status => DataExport::EXPORT_STATUS[:started]
                        )
    data_export_record.save
    Sidekiq::Testing.inline! do
      post :account_export, construct_params({})
    end
    assert_response 400
    match_json([{"code"=>"invalid_value", 
                  "field"=>"data_export", 
                  "message"=>"Currently one data export is running. Please try again later!"}])
    @account.data_exports.destroy_all
  end
  
  def test_export_user_data_when_already_failed
    Helpdesk::ExportDataWorker.any_instance.unstub(:export_users_data)
    
    data_export_record = @account.data_exports.new(
                        :source => DataExport::EXPORT_TYPE[:backup], 
                        :user => User.current,
                        :status => DataExport::EXPORT_STATUS[:failed]
                        )
    data_export_record.save
    Sidekiq::Testing.inline! do
      post :account_export, construct_params({})
    end
    assert_response 204
    data_export = @account.data_exports.data_backup[0]
    assert_equal data_export.status, DataExport::EXPORT_STATUS[:completed]
    assert_equal data_export.source, DataExport::EXPORT_TYPE[:backup]
    assert_equal data_export.last_error, nil
    assert_equal 2, @account.data_exports.count
    @account.data_exports.destroy_all
  end
  
  def test_export_user_data_when_already_completed
    Helpdesk::ExportDataWorker.any_instance.unstub(:export_users_data)
    
    data_export_record = @account.data_exports.new(
                        :source => DataExport::EXPORT_TYPE[:backup], 
                        :user => User.current,
                        :status => DataExport::EXPORT_STATUS[:completed]
                        )
    data_export_record.save
    
    data_export_record = @account.data_exports
    Sidekiq::Testing.inline! do
      post :account_export, construct_params({})
    end
    assert_response 204
    data_export = @account.data_exports.data_backup[0]
    assert_equal data_export.status, DataExport::EXPORT_STATUS[:completed]
    assert_equal data_export.source, DataExport::EXPORT_TYPE[:backup]
    assert_equal data_export.last_error, nil
    assert_equal 2, @account.data_exports.count
    @account.data_exports.destroy_all
  end
  
end