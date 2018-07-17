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
  # include TicketFieldsSandboxHelper
  # include TicketTemplatesSandboxHelper
  include TagsSandboxHelper
  include RolesSandboxHelper
  include SlaPoliciesSandboxHelper
  include EmailNotificationsSandboxHelper
  include CompanyFormSandboxHelper
  include ContactFormSandboxHelper
  include CustomSurveysSandboxHelper
  include StatusGroupsSandboxHelper
  include GroupsSandboxHelper
  include VaRulesSandboxHelper
  include SkillsSandboxHelper
  include CannedResponsesSandboxHelper
  include AccountTestHelper

  SUCCESS = 200..299

  def setup
    super
  end

  def tear_down
    Account.unstub(:current)
    super
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
    @production_account.reload
    s = ::Sync::Workflow.new(@sandbox_account_id)
    s.sync_config_from_production(committer)
    s.sync_config_from_sandbox(committer)
    @job.mark_as!(:diff_complete)
  end

  def merge_with_sandbox
    committer = {
        :name  => User.current.name,
        :email => User.current.email
    }
    @production_account.make_current
    ::Sync::Workflow.new(@sandbox_account_id, false).move_sandbox_config_to_prod(committer)
    @job.mark_as!(:merge_complete)
  end

  def test_merge_sandbox
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
      compare_data(diff_data, @production_account)
    end
  ensure
    update_data_for_delete_sandbox(@sandbox_account_id)
    @production_account.make_current
    Admin::Sandbox::DeleteWorker.new.perform
    delete_sandbox_data(@sandbox_account_id)
  end
end
