require_relative '../../unit_test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'models', 'helpers', 'freshchat_account_test_helper.rb')
require Rails.root.join('spec', 'support', 'user_helper.rb')
require 'webmock/minitest'
WebMock.allow_net_connect!

class Freshchat::AgentUtilTest < ActiveSupport::TestCase
  include Redis::OthersRedis
  include AccountTestHelper
  include FreshchatAccountTestHelper
  include Freshchat::AgentUtil
  include UsersHelper

  def setup
    if @account.blank?
      create_test_account
      @account = Account.current
      @account.save
    end
    @fchat_account = Freshchat::Account.where(account_id: Account.current.id).first
    @fchat_account ||= create_freshchat_account Account.current
  end

  def tear_down
    Account.reset_current_account
  end

  def test_destroy_agent_in_freshchat
    stubs(:freshchat_domain).returns('test-freshchat.freshpo.com')
    user = add_test_agent(@account, role: Role.find_by_name('Account Administrator').id)
    stubs(:freshid_uuid).returns(SecureRandom.uuid)
    agent = Account.current.agents.find_by_user_id(user.id)
    enable_freshchat(agent)
    agent.reload
    stub_request(:delete, %r{^https://test-freshchat.freshpo.com/v2/agents.*?$}).to_return(status: 200)
    mock = Minitest::Mock.new
    stubs(:fetch_http_action).returns('delete')
    mock.expect(:call, true, ["Freshchat Agent delete API called for Account #{Account.current.id} and for Agent #{agent.id}"])
    Rails.logger.stub :debug, mock do
      safe_send(:handle_fchat_agent, agent)
    end
    assert_equal mock.verify, true
  ensure
    unstub(:fetch_http_action)
    unstub(:freshid_uuid)
    unstub(:freshchat_domain)
  end

  def test_exception_in_freshchat
    stubs(:freshchat_domain).returns('test-freshchat.freshpo.com')
    user = add_test_agent(@account, role: Role.find_by_name('Account Administrator').id)
    agent = Account.current.agents.find_by_user_id(user.id)
    stub_request(:post, %r{^https://test-freshchat.freshpo.com/v2/agents.*?$}).to_return(body: { 'message' => 'invalid params/values' }.to_json, headers: { 'Content-Type' => 'application/json' }, status: 400)
    mock = Minitest::Mock.new
    stubs(:fetch_http_action).returns('post')
    mock.expect(:call, true, ["Exception in Freshchat Agent post API :: Response status: 400:: Response Body: invalid params/values for Account #{Account.current.id} and for Agent #{agent.id}"])
    Rails.logger.stub :error, mock do
      safe_send(:handle_fchat_agent, agent)
    end
    assert_equal mock.verify, true
  ensure
    unstub(:fetch_http_action)
    unstub(:freshchat_domain)
  end

  def test_update_agent_in_freshchat
    stubs(:freshchat_domain).returns('test-freshchat.freshpo.com')
    user = add_test_agent(@account, role: Role.find_by_name('Account Administrator').id)
    freshid_authorization = user.authorizations.build(provider: Freshid::Constants::FRESHID_PROVIDER, uid: SecureRandom.uuid)
    User.any_instance.stubs(:freshid_authorization).returns(freshid_authorization)
    agent = Account.current.agents.find_by_user_id(user.id)
    enable_freshchat(agent)
    agent.reload
    stub_request(:put, %r{^https://test-freshchat.freshpo.com/v2/agents.*?$}).to_return(body: { 'is_deactivated' => true }.to_json, headers: { 'Content-Type' => 'application/json' }, status: 200)
    mock = Minitest::Mock.new
    stubs(:fetch_http_action).returns('put')
    mock.expect(:call, true, ["Freshchat Agent put API called for Account #{Account.current.id} and for Agent #{agent.id}"])
    Rails.logger.stub :debug, mock do
      safe_send(:handle_fchat_agent, agent)
    end
    assert_equal mock.verify, true
  ensure
    unstub(:fetch_http_action)
    User.any_instance.unstub(:freshid_authorization)
    unstub(:freshchat_domain)
  end

  def test_update_agent_in_freshchat_with_no_freshid_uuid
    stubs(:freshchat_domain).returns('test-freshchat.freshpo.com')
    user = add_test_agent(@account, role: Role.find_by_name('Account Administrator').id)
    agent = Account.current.agents.find_by_user_id(user.id)
    enable_freshchat(agent)
    agent.reload
    mock = Minitest::Mock.new
    stubs(:fetch_http_action).returns('put')
    mock.expect(:call, true, ["Exception in Freshchat Agent put API :: FreshID uuid not present for Account #{Account.current.id} and for Agent #{agent.id}"])
    Rails.logger.stub :error, mock do
      safe_send(:handle_fchat_agent, agent)
    end
    assert_equal mock.verify, true
  ensure
    unstub(:fetch_http_action)
    unstub(:freshchat_domain)
  end

  def test_create_user_with_single_name_in_freshchat
    stubs(:freshchat_domain).returns('test-freshchat.freshpo.com')
    user = add_test_agent(@account, role: Role.where(name: 'Agent').first.try(:id))
    agent = Account.current.agents.where(user_id: user.id).first
    user_first_name = 'Sample'
    user.name = user_first_name
    user.save!
    stub_request(:post, 'https://test-freshchat.freshpo.com/v2/agents?skip_email_activation=true').to_return(status: 200)
    safe_send(:handle_fchat_agent, agent)
    assert_requested(:post, 'https://test-freshchat.freshpo.com/v2/agents?skip_email_activation=true', times: 1) do |req|
      request = JSON.parse(req.body)
      !request.key?('last_name') && request['first_name'] == user_first_name
    end
  ensure
    unstub(:freshchat_domain)
  end

  def test_create_user_with_same_first_name_and_last_name_in_freshchat
    stubs(:freshchat_domain).returns('test-freshchat.freshpo.com')
    user = add_test_agent(@account, role: Role.where(name: 'Agent').first.try(:id))
    agent = Account.current.agents.where(user_id: user.id).first
    user_first_name = 'Sample'
    user.name = "#{user_first_name} #{user_first_name}"
    user.save!
    stub_request(:post, 'https://test-freshchat.freshpo.com/v2/agents?skip_email_activation=true').to_return(status: 200)
    safe_send(:handle_fchat_agent, agent)
    assert_requested(:post, 'https://test-freshchat.freshpo.com/v2/agents?skip_email_activation=true', times: 1) do |req|
      request = JSON.parse(req.body)
      request['last_name'] == user_first_name && request['first_name'] == user_first_name
    end
  ensure
    unstub(:freshchat_domain)
  end

  def test_create_user_with_first_name_and_last_name_in_freshchat
    stubs(:freshchat_domain).returns('test-freshchat.freshpo.com')
    user = add_test_agent(@account, role: Role.where(name: 'Agent').first.try(:id))
    agent = Account.current.agents.where(user_id: user.id).first
    user_first_name = 'Sample'
    user_last_name = 'One'
    user.name = "#{user_first_name} #{user_last_name}"
    user.save!
    stub_request(:post, 'https://test-freshchat.freshpo.com/v2/agents?skip_email_activation=true').to_return(status: 200)
    safe_send(:handle_fchat_agent, agent)
    assert_requested(:post, 'https://test-freshchat.freshpo.com/v2/agents?skip_email_activation=true', times: 1) do |req|
      request = JSON.parse(req.body)
      request['last_name'] == user_last_name && request['first_name'] == user_first_name
    end
  ensure
    unstub(:freshchat_domain)
  end

  def test_create_user_with_numerical_first_name_and_last_name_in_freshchat
    stubs(:freshchat_domain).returns('test-freshchat.freshpo.com')
    user = add_test_agent(@account, role: Role.where(name: 'Agent').first.try(:id))
    agent = Account.current.agents.where(user_id: user.id).first
    user_first_name = '313'
    user_last_name = 'One'
    user.name = "#{user_first_name} #{user_last_name}"
    user.save!
    stub_request(:post, 'https://test-freshchat.freshpo.com/v2/agents?skip_email_activation=true').to_return(status: 200)
    safe_send(:handle_fchat_agent, agent)
    assert_requested(:post, 'https://test-freshchat.freshpo.com/v2/agents?skip_email_activation=true', times: 1) do |req|
      response = JSON.parse(req.body)
      response['last_name'] == user_last_name && response['first_name'] == user_first_name
    end
  ensure
    unstub(:freshchat_domain)
  end

  def test_create_user_with_numerical_first_name_and_numerical_last_name_in_freshchat
    stubs(:freshchat_domain).returns('test-freshchat.freshpo.com')
    user = add_test_agent(@account, role: Role.where(name: 'Agent').first.try(:id))
    agent = Account.current.agents.where(user_id: user.id).first
    user_first_name = '313'
    user_last_name = '007'
    user.name = "#{user_first_name} #{user_last_name}"
    user.save!
    stub_request(:post, 'https://test-freshchat.freshpo.com/v2/agents?skip_email_activation=true').to_return(status: 200)
    safe_send(:handle_fchat_agent, agent)
    assert_requested(:post, 'https://test-freshchat.freshpo.com/v2/agents?skip_email_activation=true', times: 1) do |req|
      response = JSON.parse(req.body)
      response['last_name'] == user_last_name && response['first_name'] == user_first_name
    end
  ensure
    unstub(:freshchat_domain)
  end

  def test_create_user_with_numerical_first_name_and_last_name_middle_name_in_freshchat
    stubs(:freshchat_domain).returns('test-freshchat.freshpo.com')
    user = add_test_agent(@account, role: Role.where(name: 'Agent').first.try(:id))
    agent = Account.current.agents.where(user_id: user.id).first
    user_first_name = '313'
    user_last_name = '717 Sample'
    user.name = "#{user_first_name} #{user_last_name}"
    user.save!
    stub_request(:post, 'https://test-freshchat.freshpo.com/v2/agents?skip_email_activation=true').to_return(status: 200)
    safe_send(:handle_fchat_agent, agent)
    assert_requested(:post, 'https://test-freshchat.freshpo.com/v2/agents?skip_email_activation=true', times: 1) do |req|
      response = JSON.parse(req.body)
      response['last_name'] == user_last_name && response['first_name'] == user_first_name
    end
  ensure
    unstub(:freshchat_domain)
  end

  private

    def enable_freshchat(agent)
      additional_settings = agent.additional_settings
      additional_settings[:freshchat] = { enabled: true }
      agent.update_attribute(:additional_settings, additional_settings)
    end
end
