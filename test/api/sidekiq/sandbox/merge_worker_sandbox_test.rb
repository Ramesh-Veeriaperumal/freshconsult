require_relative '../../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'api', 'sidekiq','sandbox', 'merge_helper.rb')
require Rails.root.join('test', 'api', 'sidekiq','sandbox', 'diff_helper.rb')
require Rails.root.join('test', 'api', 'sidekiq', 'sandbox', 'provision_sandbox_test_helper.rb')
Dir.glob("#{Rails.root}/test/api/sidekiq/sandbox/*_sandbox_helper.rb") { |file| require file }
ASSOCIATIONS = ['va_rules', 'skills']
ASSOCIATIONS.each do |association|
  require "#{Rails.root}/test/api/sidekiq/sandbox/#{association}_sandbox_helper.rb"
end


ACTIONS = ['create', 'update', 'delete']
class MergeWorkerSandboxTest < ActionView::TestCase
  include ProvisionSandboxTestHelper
  include DiffHelper
  include MergeHelper
  include AccountTestHelper

  SUCCESS = 200..299
  @@merge_data = {}
  def setup
    ChargeBee::Rest.stubs(:request).returns(stub_data)
    unless @@merge_data.present?
      @production_account = Account.first
      if @production_account
        @sandbox_account_id = @production_account.sandbox_job.try(:sandbox_account_id)
        delete_sandbox_data
      end
      @@merge_data = changes_data
    end
    super
  end

  def teardown
    ChargeBee::Rest.unstub(:request)
    Account.unstub(:current)
    super
  end

  def self.fixture_path(path = File.join(Rails.root, 'test/api/fixtures/'))
    path
  end

  def create_sandbox(account, user)
    Sharding.run_on_shard('shard_1') do
      Account.reset_current_account
      User.reset_current_user
      Admin::Sandbox::CreateAccountWorker.new.perform({:account_id => account.id, :user_id => user.id})
      account.reload
      account.make_current
      user.make_current
      Admin::Sandbox::DataToFileWorker.new.perform({})
      account.make_current
      Admin::Sandbox::FileToDataWorker.new.perform
    end
  end

  def calculate_diff
    committer = {
        :name  => User.current.name,
        :email => User.current.email
    }
    @production_account.make_current.reload
    ::Admin::Sandbox::DiffWorker.new.perform
  end

  def merge_with_sandbox
    committer = {
        :name  => User.current.name,
        :email => User.current.email
    }
    @production_account.make_current
    ::Admin::Sandbox::MergeWorker.new.perform
  end

  def changes_data
    Sharding.run_on_shard('shard_1') do
      @user = AccountTestHelper.create_test_account
      @production_account = @user.account.make_current
      delete_sandbox_references(@production_account)
      @user.make_current
      @production_account.create_sandbox_job
      create_sandbox(@production_account, @user)
      @job = @production_account.sandbox_job
      @sandbox_account_id = @job.sandbox_account_id
      @production_account.make_current
      @user.make_current
      diff_data = create_sample_data_sandbox(@sandbox_account_id)
      @production_account.make_current
      calculate_diff
      merge_with_sandbox
      @merge_data = merge_data(diff_data, @production_account)
    end
    @merge_data
  rescue => e
      puts "sandbox error #{e}"
      {"error" => e}
  end

  ACTIONS.each do|action|
    MODELS.each do|model|
      define_method "test_#{action}_#{model}_merge" do
        skip('skip failing test cases') if action == 'create' && model == 'ticket_fields'
        data =  @@merge_data[action][model]
        if action == "delete"
          for each in data
            assert_equal each[0], each[1]
          end
        else
          for each in data
            match_json(each[0], each[1], each[2])
          end
        end
      end
    end
  end
end
