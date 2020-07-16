require_relative '../../api/unit_test_helper'
require_relative '../../test_helper.rb'
require_relative '../../api/helpers/test_class_methods.rb'
require_relative '../../core/helpers/users_test_helper.rb'
require_relative '../../../lib/import_csv_util'
require 'minitest/spec'
require 'faker'
require 'csv'

require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'test_case_methods.rb')

class CustomerImportTest < ActionView::TestCase
  include AccountTestHelper
  include Proactive::Constants
  include TestCaseMethods
  include ControllerTestHelper
  include UsersHelper
  include CoreUsersTestHelper
  include ImportCsvUtil

  def setup
    @account = create_test_account
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @account.stubs(:secure_attachments_enabled?).returns(true)
    AwsWrapper::S3Object.stubs(:find).returns(fixture_file_upload('files/agent_skill_import.csv'))
    AwsWrapper::S3Object.stubs(:delete).returns([])
    @import_entry = @account.create_agent_skill_import(import_status: Admin::DataImport::IMPORT_STATUS[:started])
    @import_entry.save
    @args = {
      account_id: @account.id,
      email: 'sample@freshdesk.com',
      type: 'agent_skill',
      file_path: 'files/agent_skill_import.csv',
      customers: {
        file_name: 'agent_skill_import.csv',
        file_location: 'files/agent_skill_import.csv',
        fields:  {
          name: '0',
          email: '2'
        }.stringify_keys
      },
      data_import: @import_entry.id
    }
  end

  def teardown
    @account.unstub(:secure_attachments_enabled?)
    AwsWrapper::S3Object.unstub(:find)
    AwsWrapper::S3Object.unstub(:delete)
    Account.unstub(:current)
  end

  def self.fixture_path
    File.join(Rails.root, 'test/api/fixtures/')
  end

  def test_agent_skill_import_failed_attachment
    agent_skills = Import::Skills::Agent.new(@args).import
    assert_equal @account.attachments.where(attachable_type: 'Admin::DataImport').count, 1
    errors_csv = @import_entry.attachments.all
    mail_message = UserNotifier.deliver_notify_skill_import(
      message: {
        skill_creation_success: [],
        skill_creation_failed: [],
        skill_not_found: [],
        skill_update_success: [],
        agent_update_failed: {},
        agent_not_found: []
      },
      csv_data: ',,,,,',
      attachments: errors_csv
    )
    assert_equal mail_message.to.first, 'sample@freshdesk.com'
    html_part = mail_message.html_part ? mail_message.html_part.body.decoded : nil
    assert html_part.include?(errors_csv.first.inline_url) if html_part.present?
    text_part = mail_message.text_part ? mail_message.text_part.body.decoded : nil
    assert text_part.include?(errors_csv.first.inline_url) if text_part.present?
  ensure
    @import_entry.attachments.destroy_all
    @import_entry.destroy
  end
end
