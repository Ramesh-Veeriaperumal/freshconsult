require_relative '../../api/unit_test_helper'
['group_helper.rb', 'ticket_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
require Rails.root.join('test', 'models', 'helpers', 'agent_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')
require 'sidekiq/testing'

class AgentTest < ActiveSupport::TestCase
  include CoreUsersTestHelper
  include AgentTestHelper
  include ModelsGroupsTestHelper
  include ModelsUsersTestHelper
  include GroupHelper

  # def test_agent_update_without_feature
  #   @account.rollback(:audit_logs_central_publish)
  #   CentralPublishWorker::UserWorker.jobs.clear
  #   update_agent
  #   assert_equal 0, CentralPublishWorker::UserWorker.jobs.size
  # ensure
  #   @account.launch(:audit_logs_central_publish)
  # end

  def setup
    @account = Account.first
    Account.stubs(:current).returns(Account.first)
  end

  def teardown
    Account.current.technicians.where(email: 'john.wick@gmal.com').each(&:destroy)
    Account.current.groups.where(name: %w[liverpool_fc_01 liverpool_fc_02]).each(&:destroy)
    super
    Account.unstub(:current)
  end

  def test_agent_create_publish_to_central
    CentralPublishWorker::UserWorker.jobs.clear
    agent = add_agent(@account, role: Role.find_by_name('Agent').id, available: false).agent
    # assert_equal 1, CentralPublishWorker::UserWorker.jobs.size
    job = ::CentralPublishWorker::UserWorker.jobs.last
    payload = agent.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_post_pattern(agent))
  end

  def test_agent_create_event_info
    CentralPublishWorker::UserWorker.jobs.clear
    agent = add_agent(@account, role: Role.find_by_name('Agent').id, available: false).agent
    # assert_equal 1, CentralPublishWorker::UserWorker.jobs.size
    job = ::CentralPublishWorker::UserWorker.jobs.last
    payload = agent.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_post_pattern(agent))
    event_info = agent.event_info(:create)
    event_info.must_match_json_expression(event_info_pattern())
  end

  def test_agent_update_publish_to_central
    agent = add_agent(@account, role: Role.find_by_name('Agent').id, available: false).agent
    agent.reload
    ::CentralPublishWorker::UserWorker.jobs.clear
    agent.update_attributes(available: true)
    # assert_equal 1, ::CentralPublishWorker::UserWorker.jobs.size
    job = ::CentralPublishWorker::UserWorker.jobs.last
    payload = agent.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_post_pattern(agent))
    # assert_equal 'agent_update', job['args'][0]
    # assert_equal({ 'available' => [false, true], 'active_since' => [nil, agent.active_since.iso8601] }, job['args'][1]['model_changes'])
  end

  def test_add_group_publish_to_central
    group = create_group(@account)
    agent = add_agent(@account, role: Role.find_by_name('Agent').id, available: false).agent
    agent.reload
    ::CentralPublishWorker::UserWorker.jobs.clear
    agent.agent_groups.build(group_id: group.id)
    agent.save
    # assert_equal 1, ::CentralPublishWorker::UserWorker.jobs.size
    job = ::CentralPublishWorker::UserWorker.jobs.last
    payload = agent.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_post_pattern(agent))
    # assert_equal 'agent_update', job['args'][0]
    # assert_equal({ 'groups' => { 'added' => [{'id' => group.id, 'name' => group.name}], 'removed' => [] } }, job['args'][1]['model_changes'])
  end

  def test_add_contribution_group_publish_to_central
    group = create_group(@account, name: 'liverpool_fc_01')
    agent = add_agent(@account, email: 'john.wick@gmal.com', role: Role.where(name: 'Agent').first.id, available: false, ticket_permission: 2).agent
    agent.reload
    ::CentralPublishWorker::UserWorker.jobs.clear
    enable_advanced_ticket_scopes do
      agent.build_agent_groups_attributes([], [group.id])
      agent.save
    end
    ::CentralPublishWorker::UserWorker.jobs.last
    payload = agent.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_post_pattern(agent))
  end

  def test_add_group_and_contribution_group_publish_to_central
    group1 = create_group(@account, name: 'liverpool_fc_01')
    group2 = create_group(@account, name: 'liverpool_fc_02')
    agent = add_agent(@account, email: 'john.wick@gmal.com', role: Role.where(name: 'Agent').first.id, available: false, ticket_permission: 2).agent
    agent.reload
    ::CentralPublishWorker::UserWorker.jobs.clear
    enable_advanced_ticket_scopes do
      agent.build_agent_groups_attributes([group1.id], [group2.id])
      agent.save
    end
    ::CentralPublishWorker::UserWorker.jobs.last
    payload = agent.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_post_pattern(agent))
  end

  def test_update_group_and_contribution_group_publish_to_central
    group1 = create_group(@account, name: 'liverpool_fc_01')
    group2 = create_group(@account, name: 'liverpool_fc_02')
    agent = add_agent(@account, email: 'john.wick@gmal.com', role: Role.where(name: 'Agent').first.id, available: false, ticket_permission: 2).agent
    agent.reload
    ::CentralPublishWorker::UserWorker.jobs.clear
    enable_advanced_ticket_scopes do
      agent.build_agent_groups_attributes([group1.id], [group2.id])
      agent.save
    end
    ::CentralPublishWorker::UserWorker.jobs.last
    payload = agent.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_post_pattern(agent))

    agent = Account.current.technicians.where(id: agent.user.id).first.agent
    ::CentralPublishWorker::UserWorker.jobs.clear
    enable_advanced_ticket_scopes do
      agent.build_agent_groups_attributes([group2.id], [group1.id])
      agent.save
    end
    ::CentralPublishWorker::UserWorker.jobs.last
    payload = agent.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_post_pattern(agent))
  end

  def enable_advanced_ticket_scopes
    Account.any_instance.stubs(:advanced_ticket_scopes_enabled?).returns(true)
    yield
  ensure
    Account.any_instance.unstub(:advanced_ticket_scopes_enabled?)
  end
end
