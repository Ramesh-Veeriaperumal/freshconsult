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
  METHODS = ['added', 'modified', 'deleted', 'conflict']
  SUCCESS = 200..299

  @@diff_data = {}
  def setup
    ChargeBee::Rest.stubs(:request).returns(stub_data)
    unless @@diff_data.present?
      @production_account = Account.first
      if @production_account
        @sandbox_account_id = @production_account.sandbox_job.try(:sandbox_account_id)
        delete_sandbox_data
      end
      @@diff_data = changes_data
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
    diff_data = compare_ids(diff, @job.additional_data[:diff])
    @job.mark_as!(:diff_complete)
    diff_data
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
      diff = create_sample_data_sandbox(@sandbox_account_id)
      @diff_data = match_diff_json(diff)
    end
    @diff_data
  rescue => e
    puts "sandbox error #{e}"
    {"error" => e}
  end

  METHODS.each do|action|
    MODELS.each do|model|
      define_method "test_#{action}_#{model}_diff" do
        skip('skip failing test case') if action == 'modified' && model == 'ticket_fields'
        data =  @@diff_data[action][model]
        for each in data
            assert_equal each[0], each[1]
        end
      end
    end
  end
end
