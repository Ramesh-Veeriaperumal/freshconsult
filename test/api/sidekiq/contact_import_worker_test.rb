require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'faker'

Sidekiq::Testing.fake!

require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class ContactImportWorkerTest < ActionView::TestCase
  include AccountTestHelper
  include Redis::RedisKeys
  include Redis::OthersRedis

  def setup
    @account = create_test_account
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @import_entry = @account.contact_imports.new(
      source: Admin::DataImport::IMPORT_TYPE['contact'.to_sym],
      status: Admin::DataImport::IMPORT_STATUS[:started]
    )
    @import_entry.save
    @args = {
      account_id: @account.id,
      email: 'sample@freshdesk.com',
      type: 'contact',
      customers: {
        file_name: 'contacts_import.csv',
        file_location: 'files/contacts_import.csv',
        fields:  {
          name: '0',
          email: '2'
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

  def test_contact_import
    AwsWrapper::S3Object.stubs(:find).returns(fixture_file_upload('files/contacts_import.csv'))
    AwsWrapper::S3Object.stubs(:delete).returns([])
    Account.current.tickets.stubs(:count).returns(12)
    Import::ContactWorker.new.perform(@args)
    @import_entry.reload
    assert_equal @import_entry.import_status, Admin::DataImport::IMPORT_STATUS[:completed]
    assert_equal @import_entry.source, Admin::DataImport::IMPORT_TYPE[:contact]
    assert_equal @import_entry.last_error, nil
    AwsWrapper::S3Object.unstub(:delete)
    Account.current.tickets.unstub(:count)
    AwsWrapper::S3Object.unstub(:find)
  end

  def test_contact_import_with_multiple_company
    AwsWrapper::S3Object.stubs(:find).returns(fixture_file_upload('files/contacts_import.csv'))
    AwsWrapper::S3Object.stubs(:delete).returns([])
    Account.current.tickets.stubs(:count).returns(12)
    Import::ContactWorker.new.perform(@args)
    @import_entry.reload
    assert_equal @import_entry.import_status, Admin::DataImport::IMPORT_STATUS[:completed]
    assert_equal @import_entry.source, Admin::DataImport::IMPORT_TYPE[:contact]
    assert_equal @import_entry.last_error, nil
    AwsWrapper::S3Object.unstub(:delete)
    Account.current.tickets.unstub(:count)
    AwsWrapper::S3Object.unstub(:find)
  end

  def test_import_with_parse_csv_error
    AwsWrapper::S3Object.stubs(:find).returns(fixture_file_upload('files/contacts_import.csv'))
    AwsWrapper::S3Object.stubs(:delete).returns([])
    Account.current.tickets.stubs(:count).returns(12)
    args = {
      account_id: @account.id,
      email: 'sample@freshdesk.com',
      type: 'contact',
      customers: {
        file_name: 'contacts_import.csv',
        file_location: 'files/contacts_import.csv',
        fields:  {
          name: '0',
          email: '2',
          'company_name' => '7'
        }
      },
      data_import: @import_entry.id
    }
    Import::ContactWorker.new.perform(args)
    @import_entry.reload
    assert_equal @import_entry.import_status, Admin::DataImport::IMPORT_STATUS[:completed]
    assert_equal @import_entry.source, Admin::DataImport::IMPORT_TYPE[:contact]
    AwsWrapper::S3Object.unstub(:delete)
    Account.current.tickets.unstub(:count)
    AwsWrapper::S3Object.unstub(:find)
  end

  def test_contact_import_spam_account
    AwsWrapper::S3Object.stubs(:find).returns(fixture_file_upload('files/contacts_import.csv'))
    AwsWrapper::S3Object.stubs(:delete).returns([])
    Account.current.tickets.stubs(:count).returns(8)
    Import::ContactWorker.new.perform(@args)
  rescue Exception => e
    @import_entry.reload
    assert_equal @import_entry.import_status, Admin::DataImport::IMPORT_STATUS[:blocked]
    assert_equal @import_entry.source, Admin::DataImport::IMPORT_TYPE[:contact]
    AwsWrapper::S3Object.unstub(:delete)
    Account.current.tickets.unstub(:count)
    AwsWrapper::S3Object.unstub(:find)
  end

  def test_contact_import_when_stop_redis_key_is_set
    AwsWrapper::S3Object.stubs(:find).returns(fixture_file_upload('files/contacts_import.csv'))
    AwsWrapper::S3Object.stubs(:delete).returns([])
    Account.current.tickets.stubs(:count).returns(12)
    set_others_redis_key('STOP_CONTACT_IMPORT:1', 'true')
    Import::ContactWorker.new.perform(@args)
    @import_entry.reload
    assert_equal @import_entry.import_status, Admin::DataImport::IMPORT_STATUS[:cancelled]
    assert_equal @import_entry.source, Admin::DataImport::IMPORT_TYPE[:contact]
    assert_equal @import_entry.last_error, nil
    remove_others_redis_key('STOP_COMPANY_IMPORT:1')
    AwsWrapper::S3Object.unstub(:delete)
    Account.current.tickets.unstub(:count)
    AwsWrapper::S3Object.unstub(:find)
  end
end
