require_relative '../../unit_test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
['freshcaller_test_helper.rb'].each { |file| require Rails.root.join('test', 'api', 'helpers', file) }
require Rails.root.join('spec', 'support', 'user_helper.rb')
require 'webmock/minitest'

class Freshcaller::AgentUtilTest < ActiveSupport::TestCase
  include Redis::OthersRedis
  include AccountTestHelper
  include UsersHelper
  include ::Freshcaller::TestHelper
  include ::Freshcaller::Endpoints
  include Freshcaller::AgentUtil

  def setup
    if @account.blank?
      create_test_account
      @account = Account.current
      @account.save
    end
  end

  def tear_down
    Account.reset_current_account
  end

  def test_destroy_agent_in_freshcaller
    create_freshcaller_account unless Account.current.freshcaller_account
    user = add_test_agent(@account, role: Role.find_by_name('Account Administrator').id)
    agent = user.agent
    User.stubs(:current).returns(user)
    agent.create_freshcaller_agent(
      fc_enabled: true,
      fc_user_id: 1234
    )
    agent.reload
    stub_create_users_already_present(1234, true)
    mock = Minitest::Mock.new
    mock.expect(:call, true, ["Freshcaller Agent patch API called for Account #{Account.current.id} and for Agent #{agent.id}"])
    Rails.logger.stub :debug, mock do
      safe_send(:handle_fcaller_agent, agent)
    end
    assert_equal mock.verify, true
  ensure
    User.unstub(:current)
    delete_freshcaller_account
  end

  def test_exception_in_freshcaller
    create_freshcaller_account unless Account.current.freshcaller_account
    stub_create_users_agent_limit_error
    user = add_test_agent(@account, role: Role.find_by_name('Account Administrator').id)
    User.stubs(:current).returns(user)
    agent = user.agent
    mock = Minitest::Mock.new
    mock.expect(:call, true, ["Exception in Freshcaller Agent post API :: Response status: 400:: Body: :: {\"errors\":[{\"detail\":\"Please purchase extra to add new agents\"}]} for Account #{current_account.id} and for Agent #{agent.id}"])
    Rails.logger.stub :error, mock do
      safe_send(:handle_fcaller_agent, agent)
    end
    assert_equal mock.verify, true
  ensure
    User.unstub(:current)
    delete_freshcaller_account
  end

  def test_update_agent_in_freshcaller_with_no_fc_user_id
    create_freshcaller_account unless Account.current.freshcaller_account
    user = add_test_agent(@account, role: Role.find_by_name('Account Administrator').id)
    User.stubs(:current).returns(user)
    agent = user.agent
    agent.create_freshcaller_agent(
      fc_enabled: true,
      fc_user_id: nil
    )
    agent.reload
    mock = Minitest::Mock.new
    stubs(:fetch_http_action).returns('put')
    mock.expect(:call, true, ["Exception in Freshcaller Agent patch API :: Freshcaller UserID not present for Account #{current_account.id} and for Agent #{agent.id}"])
    Rails.logger.stub :error, mock do
      safe_send(:handle_fcaller_agent, agent)
    end
    assert_equal mock.verify, true
  ensure
    User.unstub(:current)
    delete_freshcaller_account
  end
end
