require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'webmock/minitest'

Sidekiq::Testing.fake!

require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
class SbrrConfigAgentGroupTest < ActionView::TestCase
  include AccountTestHelper

  def setup
    @account = Account.first || create_new_account
    @account.make_current
  end

  def teardown
    @account.make_current.reload
  end

  def stub_agent_group_features
    Account.any_instance.stubs(:advanced_ticket_scopes_enabled?).returns(true)
    Account.any_instance.stubs(:skill_based_round_robin_enabled?).returns(true)
    Group.any_instance.stubs(:skill_based_round_robin_enabled?).returns(true)
    yield
  ensure
    Account.any_instance.unstub(:advanced_ticket_scopes_enabled?)
    Account.any_instance.unstub(:skill_based_round_robin_enabled?)
    Group.any_instance.unstub(:skill_based_round_robin_enabled?)
  end

  def test_worker_create_write_access
    stub_agent_group_features do
      assert_nothing_raised do
        SBRR::Synchronizer::UserUpdate::Config.any_instance.expects(:sync).with(:create).once
        SBRR::Config::AgentGroup.new.perform(action: :create, user_id: @account.users.first.id, group_id: @account.groups.first.id, write_access_agent: true)
      end
    end
  end

  def test_worker_create_read_access
    stub_agent_group_features do
      assert_nothing_raised do
        SBRR::Synchronizer::UserUpdate::Config.any_instance.expects(:sync).never
        SBRR::Config::AgentGroup.new.perform(action: :create, user_id: @account.users.first.id, group_id: @account.groups.first.id, write_access_agent: false)
      end
    end
  end

  def test_worker_update_read_access_to_write_access
    stub_agent_group_features do
      assert_nothing_raised do
        SBRR::Synchronizer::UserUpdate::Config.any_instance.expects(:sync).with(:update).once
        SBRR::Config::AgentGroup.new.perform(action: :update, user_id: @account.users.first.id, group_id: @account.groups.first.id, write_access_agent: true, write_access_changes: [false, true])
      end
    end
  end

  def test_worker_update_write_access_to_read_access
    stub_agent_group_features do
      assert_nothing_raised do
        SBRR::Synchronizer::UserUpdate::Config.any_instance.expects(:sync).with(:destroy).once
        SBRR::Config::AgentGroup.new.perform(action: :update, user_id: @account.users.first.id, group_id: @account.groups.first.id, write_access_agent: false, write_access_changes: [true, false])
      end
    end
  end

  def test_worker_destroy_write_access
    stub_agent_group_features do
      assert_nothing_raised do
        SBRR::Synchronizer::UserUpdate::Config.any_instance.expects(:sync).with(:destroy).once
        SBRR::Config::AgentGroup.new.perform(action: :destroy, user_id: @account.users.first.id, group_id: @account.groups.first.id, write_access_agent: true)
      end
    end
  end

  def test_worker_destroy_read_access
    stub_agent_group_features do
      assert_nothing_raised do
        SBRR::Synchronizer::UserUpdate::Config.any_instance.expects(:sync).with(:destroy).once
        SBRR::Config::AgentGroup.new.perform(action: :destroy, user_id: @account.users.first.id, group_id: @account.groups.first.id, write_access_agent: false)
      end
    end
  end
end
