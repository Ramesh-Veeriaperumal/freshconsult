require_relative '../../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'api', 'sidekiq', 'sandbox', 'diff_helper.rb')
require Rails.root.join('test', 'api', 'sidekiq', 'sandbox', 'provision_sandbox_test_helper.rb')
Dir.glob("#{Rails.root}/test/api/sidekiq/sandbox/*_sandbox_helper.rb") { |file| require file }

class DiffSandboxTest < ActionView::TestCase
  include AccountTestHelper
  include ProvisionSandboxTestHelper
  include DiffHelper

  SUCCESS = 200..299

  def setup
    super
  end

  def tear_down
    Account.unstub(:current)
    super
  end

  def self.fixture_path(path = File.join(Rails.root, 'test/api/fixtures/'))
    path
  end

  def match_diff_json(diff)
    @production_account.make_current
    committer = {
      name: User.current.name,
      email: User.current.email
    }
    @production_account.reload
    @production_account.make_current
    if @production_account.sandbox_job.try(:[], :sandbox_account_id)
      Sharding.run_on_shard('sandbox_shard_1') do
        Account.find(@production_account.sandbox_job.sandbox_account_id).reload
      end
    end
    s = ::Sync::Workflow.new(@sandbox_account_id)
    s.sync_config_from_production(committer)
    s.sync_config_from_sandbox(committer)
    @production_account.make_current
    diff_changes = s.sandbox_config_changes
    @job.additional_data[:conflict] = diff_changes[:conflict].present?
    @job.additional_data[:diff] = ::Sync::Templatization.new(diff_changes, @sandbox_account_id).build_delta
    compare_ids(diff, @job.additional_data[:diff])
    @job.mark_as!(:diff_complete)
  end

  def test_diff_sandbox
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
      diff = create_sample_data_sandbox(@sandbox_account_id)
      match_diff_json(diff)
    end
  ensure
    update_data_for_delete_sandbox(@sandbox_account_id)
    @production_account.make_current
    Admin::Sandbox::DeleteWorker.new.perform
    delete_sandbox_data(@sandbox_account_id)
  end
end
