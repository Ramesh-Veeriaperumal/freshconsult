require_relative '../../api/unit_test_helper'
require 'minitest/spec'
require 'faker'

require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'test_case_methods.rb')

class OutreachContactTest < ActionView::TestCase
  include AccountTestHelper
  include Proactive::Constants
  include TestCaseMethods

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
    setup_stubs
    file_path = 'test/api/fixtures/files/contacts_import.csv'
    output, status = Open3.capture2('wc', '-l', file_path)
    row_count = output.strip.split(' ')[0].to_i
    contact_ids = Import::Customers::OutreachContact.new(@args).import
    @import_entry.reload
    check_assert(contact_ids.size, row_count)
    clear_stubs
  end

  def test_outreach_contact_import_limit
    stub_limit_and_run('SIMPLE_OUTREACH_IMPORT_LIMIT', 2)
  end

  def test_outreach_contact_import_trial_limit
    stub_limit_and_run('SIMPLE_OUTREACH_TRIAL_LIMIT', 1)
  end
  
  def test_outreach_contact_import_for_custom_limit
    setup_stubs
    file_path = 'test/api/fixtures/files/contacts_import.csv'
    output, status = Open3.capture2('wc', '-l', file_path)
    row_count = output.strip.split(' ')[0].to_i
    Subscription.any_instance.stubs(:trial?).returns(false)
    key = CUSTOM_EMAIL_OUTREACH_LIMIT
    $redis_others.perform_redis_op('hset', key, 1, 1)
    contact_ids = Import::Customers::OutreachContact.new(@args).import
    @import_entry.reload
    $redis_others.perform_redis_op('del', key)
    check_assert(contact_ids.size, 1)
    clear_stubs
  end

  private

    def stub_limit_and_run(const_name, limit)
      stub_const(Proactive::Constants, const_name, limit) do
        setup_stubs
        current_limit = "Proactive::Constants::#{const_name}".constantize
        Import::Customers::OutreachContact.any_instance.stubs(:max_limit).returns(current_limit)
        contact_ids = Import::Customers::OutreachContact.new(@args).import
        @import_entry.reload
        assert_equal @import_entry.import_status, Admin::DataImport::IMPORT_STATUS[:completed]
        check_assert(contact_ids.size, current_limit)
        clear_stubs
      end
    end

    def setup_stubs
      AwsWrapper::S3.stubs(:read_io).returns(fixture_file_upload('files/contacts_import.csv'))
      AwsWrapper::S3.stubs(:delete).returns([])
      Import::Customers::OutreachContact.any_instance.stubs(:notify_mailer).returns(nil)
      Import::Customers::OutreachContact.any_instance.stubs(:enable_user_activation).returns(nil)
    end

    def clear_stubs
      AwsWrapper::S3.unstub(:delete)
      AwsWrapper::S3.unstub(:find)
    end

    def check_assert(ids_count, expected_count)
      assert_equal @import_entry.source, Admin::DataImport::IMPORT_TYPE[:outreach_contact]
      assert_equal @import_entry.last_error, nil
      assert_equal ids_count, expected_count
    end
end
