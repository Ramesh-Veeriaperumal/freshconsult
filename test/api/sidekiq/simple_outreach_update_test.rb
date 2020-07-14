require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'faker'

Sidekiq::Testing.fake!

class SimpleOutreachUpdateTest < ActionView::TestCase

  def setup
    Account.stubs(:current).returns(Account.first)
    Import::Customers::OutreachContact.any_instance.stubs(:import).returns([1, 2])
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
    Account.any_instance.unstub(:current)
    super
  end

  def self.fixture_path
    File.join(Rails.root, 'test/api/fixtures/')
  end

  def test_simple_outreach_update_gets_called_from_contact_worker
    AwsWrapper::S3Object.stubs(:find).returns(fixture_file_upload('files/contacts_import.csv'))
    AwsWrapper::S3Object.stubs(:delete).returns([])
    Account.current.tickets.stubs(:count).returns(12)
    Import::SimpleOutreachWorker.new.perform(@args)
    assert_equal 0, Import::SimpleOutreachWorker.jobs.size
    @import_entry.reload
    AwsWrapper::S3Object.unstub(:delete)
    Account.current.tickets.unstub(:count)
    AwsWrapper::S3Object.unstub(:find)
  end
end
