require_relative '../../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'api', 'sidekiq', 'provision_sandbox_test_helper.rb')

class DeleteSandboxTest < ActionView::TestCase
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

  def update_currency(sandbox_account_id)
    Sharding.select_shard_of(sandbox_account_id) do
      sandbox_account = Account.find(sandbox_account_id)
      currency = Subscription::Currency.find_by_name("USD")
      if currency.blank?
        currency = Subscription::Currency.create({ :name => "USD", :billing_site => "freshpo-test", 
            :billing_api_key => "fmjVVijvPTcP0RxwEwWV3aCkk1kxVg8e", :exchange_rate => 1})
      end
      subscription = sandbox_account.subscription
      subscription.set_billing_params("USD")
      subscription.state.downcase!
      subscription.sneaky_save
    end
  end

  def test_deletion_sandbox
    Sharding.run_on_shard('shard_1') do
      @user = create_test_account
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
      sandbox_account_id = job.sandbox_account_id
      update_currency(sandbox_account_id)
      create_sample_data(@account)
      Admin::Sandbox::ConfigToFileWorker.new.perform({})
      Admin::Sandbox::FileToConfigWorker.new.perform
       Integrations::Application.stubs(:find_by_name).with('jira').returns( Integrations::Application.new)
      @account.make_current
      Admin::Sandbox::DeleteWorker.new.perform
      @account.reload
      assert_equal @account.sandbox_job, nil
      sandbox_account_exists(sandbox_account_id)
      disable_background_fixtures
    end
  end
end
