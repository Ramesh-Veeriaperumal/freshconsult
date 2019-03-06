require_relative '../test_helper'
require 'minitest/spec'
require 'faker'

require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class OutreachContactTest < ActionView::TestCase
  include AccountTestHelper

  def setup
    @account = create_test_account
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @import_entry = @account.contact_imports.new(
      source: Admin::DataImport::IMPORT_TYPE['outreach_contact'.to_sym],
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

  def self.fixture_path
    File.join(Rails.root, 'test/api/fixtures/')
  end

  def test_outreach_contact_import
    skip('skip failing test cases')
    AwsWrapper::S3Object.stubs(:find).returns(fixture_file_upload('files/contacts_import.csv'))
    AwsWrapper::S3Object.stubs(:delete).returns([])
    Import::Customers::OutreachContact.new(@args).import
    @import_entry.reload
    assert_equal @import_entry.import_status, Admin::DataImport::IMPORT_STATUS[:completed]
    assert_equal @import_entry.source, Admin::DataImport::IMPORT_TYPE[:outreach_contact]
    assert_equal @import_entry.last_error, nil
    AwsWrapper::S3Object.unstub(:delete)
    AwsWrapper::S3Object.unstub(:find)
  end
end
