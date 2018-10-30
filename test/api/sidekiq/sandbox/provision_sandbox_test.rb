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
    unless @@count_data.present?
      @production_account = Account.first
      if @production_account
        @sandbox_account_id = @production_account.sandbox_job.try(:sandbox_account_id)
        delete_sandbox_data
      end
      @@count_data = count_data
      @@production_account = @production_account
    end
    super
  end

  def teardown
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
end
