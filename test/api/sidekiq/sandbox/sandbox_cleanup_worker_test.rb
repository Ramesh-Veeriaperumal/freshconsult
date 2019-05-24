require_relative '../../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'api', 'sidekiq', 'sandbox', 'provision_sandbox_test_helper.rb')

class CleanupWorkerTest < ActionView::TestCase
  include AccountTestHelper
  include ProvisionSandboxTestHelper

  GIT_ROOT_PATH = Rails.root.join('tmp', 'sandbox').to_s.freeze

  def setup
    test_cleanup_sandbox
    super
  end

  def teardown
    Account.reset_current_account
    super
  end

  def test_cleanup_sandbox
    @production_account = AccountHelper.create_test_account
    @production_account.make_current
    @production_account.launch :sandbox_single_branch
    master_account_id = @production_account.id
    create_branch(master_account_id)
    sandbox_account_id = 9999
    create_branch(sandbox_account_id)
    Admin::Sandbox::CleanupWorker.new.perform(master_account_id: master_account_id, sandbox_account_id: sandbox_account_id)
    assert_equal branch_exists?(master_account_id), false
    assert_equal branch_exists?(sandbox_account_id), false
    @production_account.rollback :sandbox_single_branch
  rescue StandardError => e
    { 'error' => e }
  end

  def create_branch(account_id)
    branch = account_id.to_s
    repo_path = "#{GIT_ROOT_PATH}/#{branch}"
    git_client = Sync::GitClient.new(repo_path, branch)
    git_client.checkout_branch unless git_client.branch_exists?(branch, true)
  end

  def branch_exists?(account_id)
    branch = account_id.to_s
    repo_path = "#{GIT_ROOT_PATH}/#{branch}"
    git_client = Sync::GitClient.new(repo_path, branch)
    git_client.branch_exists?(branch, true)
  end
end
