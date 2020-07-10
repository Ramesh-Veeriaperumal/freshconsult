require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'faker'

Sidekiq::Testing.fake!

require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class CompanyImportWorkerTest < ActionView::TestCase
  include AccountTestHelper
  include Redis::RedisKeys
  include Redis::OthersRedis

  def setup
    @account = create_test_account
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @import_entry = @account.company_imports.new(
      source: Admin::DataImport::IMPORT_TYPE['company'.to_sym],
      status: Admin::DataImport::IMPORT_STATUS[:started]
    )
    @import_entry.save
    @args = {
      account_id: @account.id,
      email: 'sample@freshdesk.com',
      type: 'company',
      customers: {
        file_name: 'companies_import.csv',
        file_location: 'files/companies_import.csv',
        fields:  {
          name: '0',
          notes: '2'
        }.stringify_keys
      },
      data_import: @import_entry.id
    }
  end

  def teardown
    Account.unstub(:current)
  end

  def self.fixture_path
    File.join(Rails.root, 'test/api/fixtures/')
  end

  def test_company_import
    AwsWrapper::S3.stubs(:read).returns(fixture_file_upload('files/companies_import.csv'))
    AwsWrapper::S3.stubs(:delete).returns([])
    Import::CompanyWorker.new.perform(@args)
    @import_entry.reload
    assert_equal @import_entry.import_status, Admin::DataImport::IMPORT_STATUS[:completed]
    assert_equal @import_entry.source, Admin::DataImport::IMPORT_TYPE[:company]
    assert_equal @import_entry.last_error, nil
    AwsWrapper::S3.unstub(:delete)
    AwsWrapper::S3.unstub(:read)
  end

  def test_company_import_when_stop_redis_key_is_set
    AwsWrapper::S3.stubs(:read).returns(fixture_file_upload('files/companies_import.csv'))
    AwsWrapper::S3.stubs(:delete).returns([])
    set_others_redis_key('STOP_COMPANY_IMPORT:1', 'true')
    Import::CompanyWorker.new.perform(@args)
    @import_entry.reload
    assert_equal @import_entry.import_status, Admin::DataImport::IMPORT_STATUS[:cancelled]
    assert_equal @import_entry.source, Admin::DataImport::IMPORT_TYPE[:company]
    assert_equal @import_entry.last_error, nil
    remove_others_redis_key('STOP_COMPANY_IMPORT:1')
    AwsWrapper::S3.unstub(:delete)
    AwsWrapper::S3.unstub(:read)
  end
end
