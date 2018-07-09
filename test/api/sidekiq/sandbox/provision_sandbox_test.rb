require_relative '../../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'api', 'sidekiq', 'sandbox', 'provision_sandbox_test_helper.rb')

class ProvisionSandboxTest < ActionView::TestCase
  include AccountTestHelper
  include ProvisionSandboxTestHelper
  SUCCESS = 200..299

  def setup
    super
  end

  def tear_down
    Account.unstub(:current)
    super
  end

  ## TODO Need to write error test cases and add more sample data before ProvisionSandbox worker
  def test_provision_sandbox
    Sharding.run_on_shard('shard_1') do
      @user = AccountTestHelper.create_test_account
      @production_account = @user.account.make_current
      delete_sandbox_references(@production_account)
      @user.make_current
      @production_account.create_sandbox_job
      enable_background_fixtures
      Account.reset_current_account
      User.reset_current_user
      Admin::Sandbox::CreateAccountWorker.new.perform({:account_id => @production_account.id, :user_id => @user.id})
      @production_account.reload
      @production_account.make_current
      @user.make_current
      job = @production_account.sandbox_job
      @sandbox_account_id = @production_account.sandbox_job.sandbox_account_id
      Admin::Sandbox::DataToFileWorker.new.perform({})
      Admin::Sandbox::FileToDataWorker.new.perform
      match_data(@production_account.id, job.sandbox_account_id)
    end
  ensure
    update_data_for_delete_sandbox(@sandbox_account_id)
    @production_account.make_current
    Admin::Sandbox::DeleteWorker.new.perform
    delete_sandbox_data(@sandbox_account_id)
  end
end
