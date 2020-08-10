require_relative '../../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'api', 'sidekiq', 'sandbox', 'provision_sandbox_test_helper.rb')

class CustomSourceSandboxTest < ActionView::TestCase
  include AccountTestHelper
  include ProvisionSandboxTestHelper
  include TicketFieldsTestHelper

  def setup
    ChargeBee::Rest.stubs(:request).returns(stub_data)
    super
  end

  def teardown
    ChargeBee::Rest.unstub(:request)
    Account.unstub(:current)
    super
  end

  def test_deletion_sandbox
    Sharding.run_on_shard('shard_1') do
      @user = AccountTestHelper.create_test_account
      @account = @user.account.make_current
      @user.make_current
      @account.create_sandbox_job
      enable_background_fixtures
      Account.reset_current_account
      User.reset_current_user
      @source1 = create_custom_source(deleted: true)
      @source2 = create_custom_source
      Admin::Sandbox::CreateAccountWorker.new.perform(account_id: @account.id, user_id: @user.id)
      @account.reload
      @account.make_current
      @user.make_current
      job = @account.sandbox_job
      @sandbox_account_id = job.sandbox_account_id
      Admin::Sandbox::DataToFileWorker.new.perform({})
      Admin::Sandbox::FileToDataWorker.new.perform
      validate_custom_source
      disable_background_fixtures
    end
  end

  def validate_custom_source
    Sharding.run_on_shard('sandbox_shard_1') do
      sandbox_account = Account.where(id: @sandbox_account_id).first.make_current
      source1 = sandbox_account.helpdesk_sources.where(name: @source1.name).first
      source2 = sandbox_account.helpdesk_sources.where(name: @source2.name).first
      assert_not_nil source1
      assert_not_nil source2
      assert source1.deleted
      source3 = create_custom_source
      assert_equal 102, source3.account_choice_id
    end
  ensure
    @account.make_current
  end
end
