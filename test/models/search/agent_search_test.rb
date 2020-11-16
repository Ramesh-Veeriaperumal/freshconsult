# frozen_string_literal: true

require_relative '../test_helper'
require Rails.root.join('test', 'core', 'helpers', 'groups_test_helper.rb')
require 'faker'

class Search::AgentSearchTest < ActiveSupport::TestCase
  include AccountTestHelper
  include CoreUsersTestHelper
  include GroupsTestHelper
  include ::Admin::AdvancedTicketing::FieldServiceManagement::Util

  def setup
    create_test_account if @account.nil?
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_support_agent_push_to_search
    agent_type_id = @account.agent_types.find_by_name(Agent::SUPPORT_AGENT).agent_type_id
    user = add_test_agent(@account, agent_type: agent_type_id)
    payload = JSON.parse(user.to_esv2_json)
    es_attribute = user.agent_es_attributes
    assert_equal es_attribute[:agent_type], user.agent.agent_type
    assert_equal es_attribute[:group_ids], user.agent.group_ids
    assert_equal es_attribute[:contribution_group_ids], user.agent.contribution_group_ids
    assert_equal payload['agent_type'], user.agent.agent_type
    assert_equal payload['group_ids'], user.agent.group_ids
    assert_equal payload['contribution_group_ids'], user.agent.contribution_group_ids
  ensure
    user.try(:destroy)
  end

  def test_field_agent_push_to_search
    create_field_agent_type
    agent_type_id = @account.agent_types.find_by_name(Agent::FIELD_AGENT).agent_type_id
    user = add_test_agent(@account, agent_type: agent_type_id)
    payload = JSON.parse(user.to_esv2_json)
    es_attribute = user.agent_es_attributes
    assert_equal es_attribute[:agent_type], user.agent.agent_type
    assert_equal es_attribute[:group_ids], user.agent.group_ids
    assert_equal es_attribute[:contribution_group_ids], user.agent.contribution_group_ids
    assert_equal payload['agent_type'], user.agent.agent_type
    assert_equal payload['group_ids'], user.agent.group_ids
    assert_equal payload['contribution_group_ids'], user.agent.contribution_group_ids
  ensure
    user.try(:destroy)
  end

  def test_support_agent_with_group_ids_push_to_search
    agent_type_id = @account.agent_types.find_by_name(Agent::SUPPORT_AGENT).agent_type_id
    user = add_test_agent(@account, agent_type: agent_type_id)
    group_with_agent = create_group_with_agents(@account, agent_list: [user.id])
    payload = JSON.parse(user.to_esv2_json)
    es_attribute = user.agent_es_attributes
    assert_equal es_attribute[:agent_type], user.agent.agent_type
    assert_equal es_attribute[:group_ids], user.agent.group_ids
    assert_equal es_attribute[:contribution_group_ids], user.agent.contribution_group_ids
    assert_equal payload['group_ids'], user.agent.group_ids
    assert_equal payload['contribution_group_ids'], user.agent.contribution_group_ids
  ensure
    user.try(:destroy)
    group_with_agent.try(:destroy)
  end

  def test_field_agent_with_group_ids_push_to_search
    create_field_tech_role
    create_field_agent_type
    agent_type_id = @account.agent_types.find_by_name(Agent::FIELD_AGENT).agent_type_id
    user = add_test_agent(@account, agent_type: agent_type_id, role: Role.find_by_name('Field technician').id)
    group_type = GroupType.create(name: 'field_agent_group', account_id: @account.id, group_type_id: 2)
    group = create_group_with_agents(@account, group_type: group_type.group_type_id, agent_list: [user.id])
    payload = JSON.parse(user.to_esv2_json)
    es_attribute = user.agent_es_attributes
    assert_equal es_attribute[:agent_type], user.agent.agent_type
    assert_equal es_attribute[:group_ids], user.agent.group_ids
    assert_equal es_attribute[:contribution_group_ids], user.agent.contribution_group_ids
    assert_equal payload['group_ids'], user.agent.group_ids
    assert_equal payload['contribution_group_ids'], user.agent.contribution_group_ids
  ensure
    user.try(:destroy)
    group.try(:destroy)
  end

  def test_support_agent_with_contribution_group_push_to_search
    agent_type_id = @account.agent_types.find_by_name(Agent::SUPPORT_AGENT).agent_type_id
    user = add_test_agent(@account, agent_type: agent_type_id)
    group_with_agent = create_group_with_agents(@account, agent_list: [user.id])
    group_with_agent.agent_groups.where(user_id: user.id).each do |agent_group|
      agent_group.write_access = false
      agent_group.save
    end
    payload = JSON.parse(user.to_esv2_json)
    es_attribute = user.agent_es_attributes
    assert_equal es_attribute[:agent_type], user.agent.agent_type
    assert_equal es_attribute[:group_ids], user.agent.group_ids
    assert_equal es_attribute[:contribution_group_ids], user.agent.contribution_group_ids
    assert_equal payload['group_ids'], user.agent.group_ids
    assert_equal payload['contribution_group_ids'], user.agent.contribution_group_ids
  ensure
    user.try(:destroy)
    group_with_agent.try(:destroy)
  end

  def test_field_agent_with_contribution_group_push_to_search
    create_field_tech_role
    create_field_agent_type
    agent_type_id = @account.agent_types.find_by_name(Agent::FIELD_AGENT).agent_type_id
    user = add_test_agent(@account, agent_type: agent_type_id, role: Role.find_by_name('Field technician').id)
    group_type = GroupType.create(name: 'field_agent_group', account_id: @account.id, group_type_id: 2)
    group_with_agent = create_group_with_agents(@account, group_type: group_type.group_type_id, agent_list: [user.id])
    group_with_agent.agent_groups.where(user_id: user.id).each do |agent_group|
      agent_group.write_access = false
      agent_group.save
    end
    payload = JSON.parse(user.to_esv2_json)
    es_attribute = user.agent_es_attributes
    assert_equal es_attribute[:agent_type], user.agent.agent_type
    assert_equal es_attribute[:group_ids], user.agent.group_ids
    assert_equal es_attribute[:contribution_group_ids], user.agent.contribution_group_ids
    assert_equal payload['group_ids'], user.agent.group_ids
    assert_equal payload['contribution_group_ids'], user.agent.contribution_group_ids
  ensure
    user.try(:destroy)
    group_with_agent.try(:destroy)
  end

  def test_support_agent_deleted_push_to_search
    agent_type_id = @account.agent_types.find_by_name(Agent::SUPPORT_AGENT).agent_type_id
    user = add_test_agent(@account, agent_type: agent_type_id)
    RabbitmqWorker.clear
    user.agent.destroy
    assert_equal RabbitmqWorker.jobs.size, 1
    assert_equal RabbitmqWorker.jobs[0]['args'][0], 'users'
  ensure
    user.try(:destroy)
  end

  def test_normal_user_search_publish_payload
    user = Account.current.all_contacts.first
    payload = JSON.parse(user.to_esv2_json)
    es_attribute = user.agent_es_attributes
    assert_equal es_attribute[:agent_type].nil?, true
    assert_equal es_attribute[:group_ids].nil?, true
    assert_equal es_attribute[:contribution_group_ids].nil?, true
    assert_equal payload['group_ids'].nil?, true
    assert_equal payload['contribution_group_ids'].nil?, true
    assert_equal payload['agent_type'].nil?, true
  end
end
