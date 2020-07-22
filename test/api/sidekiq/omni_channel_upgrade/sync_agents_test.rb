require_relative '../../unit_test_helper'
['account_test_helper.rb', 'users_test_helper.rb'].each { |file| require Rails.root.join('test', 'core', 'helpers', file) }
require 'sidekiq/testing'
require 'webmock/minitest'

Sidekiq::Testing.fake!

class OmniChannelUpgrade::SyncAgentsTest < ActionView::TestCase
  include AccountTestHelper
  include CoreUsersTestHelper

  FRESHCALLER = 'freshcaller'.freeze
  FRESHCHAT = 'freshchat'.freeze

  def setup
    super
    create_test_account
    @user = add_agent(Account.current)
    Agent.any_instance.stubs(:save!).returns(true)
  end

  def teardown
    Agent.any_instance.unstub(:save!)
    @user.destroy
    super
  end

  def test_sync_agents_worker_should_fail_when_freshcaller_agent_not_enabled
    performer_id = @user.agent.id
    Agent.any_instance.stubs(:agent_freshcaller_enabled?).returns(false)
    error = assert_raises RuntimeError do
      OmniChannelUpgrade::SyncAgents.new.perform(performer_id: performer_id, product_name: FRESHCALLER)
    end
    assert_equal error.message, 'Freshcaller agent sync failed'
  ensure
    Agent.any_instance.unstub(:agent_freshcaller_enabled?)
  end

  def test_sync_agents_worker_should_fail_when_freshchat_agent_not_enabled
    performer_id = @user.agent.id
    Agent.any_instance.stubs(:agent_freshchat_enabled?).returns(false)
    error = assert_raises RuntimeError do
      OmniChannelUpgrade::SyncAgents.new.perform(performer_id: performer_id, product_name: FRESHCHAT)
    end
    assert_equal error.message, 'Freshchat agent sync failed'
  ensure
    Agent.any_instance.unstub(:agent_freshchat_enabled?)
  end

  def test_sync_agents_worker_executes_for_freshcaller_without_error
    performer_id = @user.agent.id
    Agent.any_instance.stubs(:agent_freshcaller_enabled?).returns(true)
    assert_nothing_raised do
      OmniChannelUpgrade::SyncAgents.new.perform(performer_id: performer_id, product_name: FRESHCALLER)
    end
  ensure
    Agent.any_instance.unstub(:agent_freshcaller_enabled?)
  end

  def test_sync_agents_worker_executes_for_freshchat_without_error
    performer_id = @user.agent.id
    Agent.any_instance.stubs(:agent_freshchat_enabled?).returns(true)
    assert_nothing_raised do
      OmniChannelUpgrade::SyncAgents.new.perform(performer_id: performer_id, product_name: FRESHCHAT)
    end
  ensure
    Agent.any_instance.unstub(:agent_freshchat_enabled?)
  end
end
