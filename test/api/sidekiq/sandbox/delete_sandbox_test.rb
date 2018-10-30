require_relative '../../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'api', 'sidekiq', 'sandbox', 'provision_sandbox_test_helper.rb')

class DeleteSandboxTest < ActionView::TestCase
  include AccountTestHelper
  include ProvisionSandboxTestHelper
  SUCCESS = 200..299

  def setup
    super
  end

  def teardown
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
      Admin::Sandbox::CreateAccountWorker.new.perform({:account_id => @account.id, :user_id => @user.id})
      @account.reload
      @account.make_current
      @user.make_current
      job = @account.sandbox_job
      @sandbox_account_id = job.sandbox_account_id
      Admin::Sandbox::DataToFileWorker.new.perform({})
      Admin::Sandbox::FileToDataWorker.new.perform
      update_data_for_delete_sandbox(@sandbox_account_id)
      @account.make_current
      Admin::Sandbox::DeleteWorker.new.perform
      @account.reload
      assert_equal @account.sandbox_job, nil
      sandbox_account_exists(@sandbox_account_id)
      disable_background_fixtures
    end
  end
end
