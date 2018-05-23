require_relative '../../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'api', 'sidekiq', 'provision_sandbox_test_helper.rb')

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
      @user = create_test_account
      @account = @user.account.make_current
      delete_sandbox_references(@account)
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
      create_sample_data(@account)
      Admin::Sandbox::ConfigToFileWorker.new.perform({})
      Admin::Sandbox::FileToConfigWorker.new.perform
      match_data(@account.id, job.sandbox_account_id)
      disable_background_fixtures
    end
  end
end
