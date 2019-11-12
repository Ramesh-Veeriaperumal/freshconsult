require_relative '../test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class DataImportTest < ActiveSupport::TestCase
  include AccountTestHelper

  def setup
    super
    @account = create_test_account if @account.nil?
    Account.current.stubs(:secure_attachments_enabled?).returns(false)
  end

  def teardown
    Account.current.unstub(:secure_attachments)
    super
  end

  def test_clear_attachments
    @account.create_agent_skill_import(import_status: Admin::DataImport::IMPORT_STATUS[:started])
    skill_import = @account.agent_skill_import
    file = File.new(Rails.root.join('spec/fixtures/files/attachment.txt'))
    failed_attachment = @account.agent_skill_import.attachments.build(content: file, account_id: @account.id)
    failed_attachment.save!
    assert failed_attachment.present?
    skill_import.destroy
    assert_equal 0, @account.attachments.where(attachable_type: 'Admin::DataImport').count
  end
end
