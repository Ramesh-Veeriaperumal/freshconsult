require_relative '../../../unit_test_helper'
require 'sidekiq/testing'
require 'faker'

Sidekiq::Testing.fake!

['agent_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
['groups_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }

require_relative 'sla_base_helper.rb'

class SlaEscalationWorkerTest < ActionView::TestCase
  include AgentHelper
  include GroupsTestHelper
  include SlaBaseHelper
  include Redis::RedisKeys
  include Redis::OthersRedis

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_sla_escalation_response_base
    agent = add_agent_to_account(@account, options = { role: 4, active: 1, email: "testxyz@yopmail.com" })
    group = create_group @account
    group.update_attributes(assign_time: 900, escalate_to: agent.user_id)
    ticket, sla_policy = create_test_ticket_sla_escalation(agent, group)
    EmailNotification.any_instance.stubs(:agent_notification).returns(true)
    set_others_redis_key(SLA_TICKETS_LIMIT, 10)
    Admin::Sla::Escalation::Base.new.perform
    ticket.reload
    check_for_correct_response_sla_escalation(ticket, agent)
  ensure
    EmailNotification.any_instance.unstub(:agent_notification)
    ticket.destroy
    sla_policy.destroy
    group.destroy
    agent.destroy
    remove_others_redis_key SLA_TICKETS_LIMIT
  end

  def test_sla_escalation_resolution_base
    agent = add_agent_to_account(@account, options = { role: 4, active: 1, email: "testxyz@yopmail.com" })
    group = create_group @account
    group.update_attributes(assign_time: 900, escalate_to: agent.user_id)
    ticket, sla_policy = create_test_ticket_sla_escalation(agent, group)
    EmailNotification.any_instance.stubs(:agent_notification).returns(true)
    set_others_redis_key(SLA_TICKETS_LIMIT, 10)
    Admin::Sla::Escalation::Base.new.perform
    ticket.reload
    check_for_correct_resolution_sla_escalation(ticket, agent)
  ensure
    EmailNotification.any_instance.unstub(:agent_notification)
    ticket.destroy
    sla_policy.destroy
    group.destroy
    agent.destroy
    remove_others_redis_key SLA_TICKETS_LIMIT
  end
  def test_sla_escalation_group_base
    agent = add_agent_to_account(@account, options = { role: 4, active: 1, email: "testxyz@yopmail.com" })
    group = create_group @account
    group.update_attributes(assign_time: 900, escalate_to: agent.user_id)
    ticket, sla_policy = create_test_ticket_sla_escalation(agent, group)
    EmailNotification.any_instance.stubs(:agent_notification).returns(true)
    set_others_redis_key(SLA_TICKETS_LIMIT, 10)
    Admin::Sla::Escalation::Base.new.perform
    ticket.reload
    check_for_correct_group_sla_escalation(ticket, agent)
  ensure
    EmailNotification.any_instance.unstub(:agent_notification)
    ticket.destroy
    sla_policy.destroy
    group.destroy
    agent.destroy
    remove_others_redis_key SLA_TICKETS_LIMIT
  end
  def test_sla_escalation_response_trial
    agent = add_agent_to_account(@account, options = { role: 4, active: 1, email: "testxyz@yopmail.com" })
    group = create_group @account
    group.update_attributes(assign_time: 900, escalate_to: agent.user_id)
    ticket, sla_policy = create_test_ticket_sla_escalation(agent, group)
    EmailNotification.any_instance.stubs(:agent_notification).returns(true)
    set_others_redis_key(SLA_TICKETS_LIMIT, 10)
    Admin::Sla::Escalation::Trial.new.perform
    ticket.reload
    check_for_correct_response_sla_escalation(ticket, agent)
  ensure
    EmailNotification.any_instance.unstub(:agent_notification)
    ticket.destroy
    sla_policy.destroy
    group.destroy
    agent.destroy
    remove_others_redis_key SLA_TICKETS_LIMIT
  end
  def test_sla_escalation_resolution_trial
    agent = add_agent_to_account(@account, options = { role: 4, active: 1, email: "testxyz@yopmail.com" })
    group = create_group @account
    group.update_attributes(assign_time: 900, escalate_to: agent.user_id)
    ticket, sla_policy = create_test_ticket_sla_escalation(agent, group)
    EmailNotification.any_instance.stubs(:agent_notification).returns(true)
    set_others_redis_key(SLA_TICKETS_LIMIT, 10)
    Admin::Sla::Escalation::Trial.new.perform
    ticket.reload
    check_for_correct_resolution_sla_escalation(ticket, agent)
  ensure
    EmailNotification.any_instance.unstub(:agent_notification)
    ticket.destroy
    sla_policy.destroy
    group.destroy
    agent.destroy
    remove_others_redis_key SLA_TICKETS_LIMIT
  end
  def test_sla_escalation_group_trial
    agent = add_agent_to_account(@account, options = { role: 4, active: 1, email: "testxyz@yopmail.com" })
    group = create_group @account
    group.update_attributes(assign_time: 900, escalate_to: agent.user_id)
    ticket, sla_policy = create_test_ticket_sla_escalation(agent, group)
    EmailNotification.any_instance.stubs(:agent_notification).returns(true)
    set_others_redis_key(SLA_TICKETS_LIMIT, 10)
    Admin::Sla::Escalation::Trial.new.perform
    ticket.reload
    check_for_correct_group_sla_escalation(ticket, agent)
  ensure
    EmailNotification.any_instance.unstub(:agent_notification)
    ticket.destroy
    sla_policy.destroy
    group.destroy
    agent.destroy
    remove_others_redis_key SLA_TICKETS_LIMIT
  end
  def test_sla_escalation_response_free
    agent = add_agent_to_account(@account, options = { role: 4, active: 1, email: "testxyz@yopmail.com" })
    group = create_group @account
    group.update_attributes(assign_time: 900, escalate_to: agent.user_id)
    ticket, sla_policy = create_test_ticket_sla_escalation(agent, group)
    EmailNotification.any_instance.stubs(:agent_notification).returns(true)
    set_others_redis_key(SLA_TICKETS_LIMIT, 10)
    Admin::Sla::Escalation::Free.new.perform
    ticket.reload
    check_for_correct_response_sla_escalation(ticket, agent)
  ensure
    EmailNotification.any_instance.unstub(:agent_notification)
    ticket.destroy
    sla_policy.destroy
    group.destroy
    agent.destroy
    remove_others_redis_key SLA_TICKETS_LIMIT
  end
  def test_sla_escalation_resolution_free
    agent = add_agent_to_account(@account, options = { role: 4, active: 1, email: "testxyz@yopmail.com" })
    group = create_group @account
    group.update_attributes(assign_time: 900, escalate_to: agent.user_id)
    ticket, sla_policy = create_test_ticket_sla_escalation(agent, group)
    EmailNotification.any_instance.stubs(:agent_notification).returns(true)
    set_others_redis_key(SLA_TICKETS_LIMIT, 10)
    Admin::Sla::Escalation::Free.new.perform
    ticket.reload
    check_for_correct_resolution_sla_escalation(ticket, agent)
  ensure
    EmailNotification.any_instance.unstub(:agent_notification)
    ticket.destroy
    sla_policy.destroy
    group.destroy
    agent.destroy
    remove_others_redis_key SLA_TICKETS_LIMIT
  end
  def test_sla_escalation_group_free
    agent = add_agent_to_account(@account, options = { role: 4, active: 1, email: "testxyz@yopmail.com" })
    group = create_group @account
    group.update_attributes(assign_time: 900, escalate_to: agent.user_id)
    ticket, sla_policy = create_test_ticket_sla_escalation(agent, group)
    EmailNotification.any_instance.stubs(:agent_notification).returns(true)
    set_others_redis_key(SLA_TICKETS_LIMIT, 10)
    Admin::Sla::Escalation::Free.new.perform
    ticket.reload
    check_for_correct_group_sla_escalation(ticket, agent)
  ensure
    EmailNotification.any_instance.unstub(:agent_notification)
    ticket.destroy
    sla_policy.destroy
    group.destroy
    agent.destroy
    remove_others_redis_key SLA_TICKETS_LIMIT
  end
  def test_sla_escalation_response_premium
    agent = add_agent_to_account(@account, options = { role: 4, active: 1, email: "testxyz@yopmail.com" })
    group = create_group @account
    group.update_attributes(assign_time: 900, escalate_to: agent.user_id)
    ticket, sla_policy = create_test_ticket_sla_escalation(agent, group)
    EmailNotification.any_instance.stubs(:agent_notification).returns(true)
    set_others_redis_key(SLA_TICKETS_LIMIT, 10)
    Admin::Sla::Escalation::Premium.new.perform
    ticket.reload
    check_for_correct_response_sla_escalation(ticket, agent)
  ensure
    EmailNotification.any_instance.unstub(:agent_notification)
    ticket.destroy
    sla_policy.destroy
    group.destroy
    agent.destroy
    remove_others_redis_key SLA_TICKETS_LIMIT
  end
  def test_sla_escalation_resolution_premium
    agent = add_agent_to_account(@account, options = { role: 4, active: 1, email: "testxyz@yopmail.com" })
    group = create_group @account
    group.update_attributes(assign_time: 900, escalate_to: agent.user_id)
    ticket, sla_policy = create_test_ticket_sla_escalation(agent, group)
    EmailNotification.any_instance.stubs(:agent_notification).returns(true)
    set_others_redis_key(SLA_TICKETS_LIMIT, 10)
    Admin::Sla::Escalation::Premium.new.perform
    ticket.reload
    check_for_correct_resolution_sla_escalation(ticket, agent)
  ensure
    EmailNotification.any_instance.unstub(:agent_notification)
    ticket.destroy
    sla_policy.destroy
    group.destroy
    agent.destroy
    remove_others_redis_key SLA_TICKETS_LIMIT
  end
  def test_sla_escalation_group_premium
    agent = add_agent_to_account(@account, options = { role: 4, active: 1, email: "testxyz@yopmail.com" })
    group = create_group @account
    group.update_attributes(assign_time: 900, escalate_to: agent.user_id)
    ticket, sla_policy = create_test_ticket_sla_escalation(agent, group)
    EmailNotification.any_instance.stubs(:agent_notification).returns(true)
    set_others_redis_key(SLA_TICKETS_LIMIT, 10)
    Admin::Sla::Escalation::Premium.new.perform
    ticket.reload
    check_for_correct_group_sla_escalation(ticket, agent)
  ensure
    EmailNotification.any_instance.unstub(:agent_notification)
    ticket.destroy
    sla_policy.destroy
    group.destroy
    agent.destroy
    remove_others_redis_key SLA_TICKETS_LIMIT
  end
end