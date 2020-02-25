require_relative '../../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'api', 'sidekiq', 'sandbox', 'provision_sandbox_test_helper.rb')

class ProvisionSandboxTest < ActionView::TestCase
  include AccountTestHelper
  include ProvisionSandboxTestHelper
  SUCCESS = 200..299
  @@count_data = {}

  def setup
    ChargeBee::Rest.stubs(:request).returns(stub_data)
    unless @@count_data.present?
      @@count_data = count_data
      @@production_account = @production_account
    end
    super
  end

  def teardown
    delete_sandbox_data
    delete_sandbox_references @production_account
    ChargeBee::Rest.unstub(:request)
    Account.unstub(:current)
    super
  end

  def count_data
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
      @production_account.make_current
      @models_data = models_data(@production_account.id, job.sandbox_account_id)
    end
    @models_data
  rescue => e
    {"error" => e}
  end

  def master_account_data(table)
    @@count_data[:master_account_data][table].sort.map{|v| IGNORE_TABLES_FOR_OFFSET.include?(table) ? v : v + offset(@@production_account.id)}
  end

  (MODEL_DEPENDENCIES.keys.map {|table| MODEL_TABLE_MAPPING[table]}.compact - IGNORE_TABLES).each do |table|
    define_method "test_create_sandbox_#{table}" do
      assert_equal master_account_data(table), @@count_data[:sandbox_account_data][table].sort
    end
  end

  def test_domain_update_worker_with_domain_change
    Sidekiq::Testing.inline! do
      Sharding.run_on_shard ('shard_1') do
        @production_account.reload
        @production_account.make_current
        previous_full_domain = @production_account.full_domain
        @production_account.full_domain = 'kryptonians.freshdesk.com'
        @production_account.save!
        assert_equal Sidekiq::Queue.new('update_url_in_sandbox').size, 1
        @production_account.reload
        Sharding.select_shard_of(@sandbox_account_id) do
          @sandbox_account = Account.find(@sandbox_account_id)
          production_url_in_sandbox = @sandbox_account.account_additional_settings.additional_settings[:sandbox][:production_url]
          assert_equal production_url_in_sandbox, @production_account.full_domain
        end
      end
    end
  ensure
    @production_account.full_domain = previous_full_domain
    Account.reset_current_account
  end

  def test_domain_update_worker_without_domain_change
    Sidekiq::Testing.inline! do
      Sharding.run_on_shard ('shard_1') do
        @production_account.reload
        @production_account.make_current
        previous_name = @production_account.name
        @production_account.name = 'Kryptonian Account'
        @production_account.save!
        assert_equal Sidekiq::Queue.new('update_url_in_sandbox').size, 0
      end
    end
  ensure
    @production_account.full_domain = previous_full_domain
    @production_account.name = previous_name
  end
end
