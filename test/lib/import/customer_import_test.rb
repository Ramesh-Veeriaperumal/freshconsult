require_relative '../../api/unit_test_helper'
require 'minitest/spec'
require 'faker'

require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'test_case_methods.rb')

class CustomerImportTest < ActionView::TestCase
  include AccountTestHelper
  include Proactive::Constants
  include TestCaseMethods

  def setup
    @account = create_test_account
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @account.stubs(:secure_attachments_enabled?).returns(true)
  end

  def teardown
    @account.unstub(:secure_attachments_enabled?)
    Import::Customers::Contact.any_instance.unstub(:enable_user_activation)
    Import::Customers::Contact.any_instance.unstub(:notify_mailer)
    Import::Customers::OutreachContact.any_instance.unstub(:enable_user_activation)
    Import::Customers::OutreachContact.any_instance.unstub(:notify_mailer)
    AwsWrapper::S3Object.unstub(:find)
    AwsWrapper::S3Object.unstub(:delete)
    Account.unstub(:current)
  end

  def self.fixture_path
    File.join(Rails.root, 'test/api/fixtures/')
  end

  def test_contact_import_failed_attachment
    setup_stubs 'contact'
    contact_ids = Import::Customers::Contact.new(@args).import
    assert_equal @account.attachments.where(attachable_type: 'Admin::DataImport').count, 1
    errors_csv = @import_entry.attachments.all
    hash = {
      user: @account.users.find_by_id(1),
      type: 'user'.pluralize,
      created_count: 1,
      updated_count: 1,
      failed_count: 1,
      import_success: false,
      file_name: errors_csv.first[:content_file_name],
      file_path: @args[:customers][:file_location],
      attachments: errors_csv
    }
    mail_message = UserNotifier.deliver_notify_customers_import(hash)
    assert_equal mail_message.to.first, 'sample@freshdesk.com'
    html_part = mail_message.html_part ? mail_message.html_part.body.decoded : nil
    assert html_part.include?(errors_csv.first.inline_url) if html_part.present?
    text_part = mail_message.text_part ? mail_message.text_part.body.decoded : nil
    assert text_part.include?(errors_csv.first.inline_url) if text_part.present?
  ensure
    @import_entry.attachments.destroy_all
    @import_entry.destroy
  end

  def test_contact_import_failed_attachment_even_if_it_exceeds_five_mb
    setup_stubs('contact', 'contacts_import_fail_cases.csv')
    stub_const(ImportCsvUtil, 'FIVE_MEGABYTE', 500) do
      contact_ids = Import::Customers::Contact.new(@args).import
      assert_equal @account.attachments.where(attachable_type: 'Admin::DataImport').count, 1
    end
  ensure
    @import_entry.attachments.destroy_all
    @import_entry.destroy
  end

  def test_outreach_contact_import_failed_attachment_even_if_it_exceeds_five_mb
    setup_stubs('outreach_contact', 'contacts_import_fail_cases.csv')
    stub_const(ImportCsvUtil, 'FIVE_MEGABYTE', 500) do
      contact_ids = Import::Customers::OutreachContact.new(@args).import
      assert_equal @account.attachments.where(attachable_type: 'Admin::DataImport').count, 1
    end
  ensure
    @import_entry.attachments.destroy_all
    @import_entry.destroy
  end

  def test_outreach_contact_import_failed_attachment
    setup_stubs 'outreach_contact'
    contact_ids = Import::Customers::OutreachContact.new(@args).import
    assert_equal @account.attachments.where(attachable_type: 'Admin::DataImport').count, 1
    errors_csv = @import_entry.attachments.all
    hash = {
      user: @account.users.find_by_id(1),
      type: 'user'.pluralize,
      outreach_name: 'Sample',
      success_count: 1,
      failed_count: 1,
      file_name: errors_csv.first[:content_file_name],
      attachments: errors_csv,
      file_path: @args[:customers][:file_location]
    }
    mail_message = UserNotifier.deliver_notify_proactive_outreach_import(hash)
    assert_equal mail_message.to.first, 'sample@freshdesk.com'
    html_part = mail_message.html_part ? mail_message.html_part.body.decoded : nil
    assert html_part.include?(errors_csv.first.inline_url) if html_part.present?
    text_part = mail_message.text_part ? mail_message.text_part.body.decoded : nil
    assert text_part.include?(errors_csv.first.inline_url) if text_part.present?
  ensure
    @import_entry.attachments.destroy_all
    @import_entry.destroy
  end

  def setup_stubs(type, file_name = 'contacts2_import.csv')
    if type.eql? 'contact'
      Import::Customers::Contact.any_instance.stubs(:enable_user_activation).returns(nil)
      Import::Customers::Contact.any_instance.stubs(:notify_mailer).returns(nil)
    else
      Import::Customers::OutreachContact.any_instance.stubs(:enable_user_activation).returns(nil)
      Import::Customers::OutreachContact.any_instance.stubs(:notify_mailer).returns(nil)
    end
    AwsWrapper::S3.stubs(:find).returns(fixture_file_upload("files/#{file_name}"))
    AwsWrapper::S3.stubs(:delete).returns([])
    @import_entry = @account.contact_imports.new(
      source: Admin::DataImport::IMPORT_TYPE[type.to_sym],
      status: Admin::DataImport::IMPORT_STATUS[:started]
    )
    @import_entry.save
    @args = {
      account_id: @account.id,
      email: 'sample@freshdesk.com',
      type: 'contact',
      customers: {
        file_name: file_name,
        file_location: "files/#{file_name}",
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
end
