require_relative '../../../unit_test_helper'
require 'sidekiq/testing'
require 'faker'

Sidekiq::Testing.fake!

['agent_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
['groups_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }

require_relative 'sla_base_helper.rb'

class SlaReminderWorkerTest < ActionView::TestCase
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

  def test_sla_reminder_response_base
    agent = add_agent_to_account(@account, options = { role: 4, active: 1, email: "testxyz@yopmail.com" })
    group = create_group @account
    ticket, sla_policy = create_test_ticket_sla_reminder(agent, group)
    EmailNotification.any_instance.stubs(:agent_notification).returns(true)
    set_others_redis_key(SLA_TICKETS_LIMIT, 2)
    Admin::Sla::Reminder::Base.new.perform
    ticket.reload
    check_for_correct_response_sla_reminder(ticket, agent)
  ensure
    EmailNotification.any_instance.unstub(:agent_notification)
    ticket.destroy
    sla_policy.destroy
    group.destroy
    agent.destroy
    remove_others_redis_key SLA_TICKETS_LIMIT
  end

  def test_sla_reminder_resolution_base
    agent = add_agent_to_account(@account, options = { role: 4, active: 1, email: "testxyz@yopmail.com" })
    group = create_group @account
    ticket, sla_policy = create_test_ticket_sla_reminder(agent, group)
    EmailNotification.any_instance.stubs(:agent_notification).returns(true)
    set_others_redis_key(SLA_TICKETS_LIMIT, 2)
    Admin::Sla::Reminder::Base.new.perform
    ticket.reload
    check_for_correct_resolution_sla_reminder(ticket, agent)
  ensure
    EmailNotification.any_instance.unstub(:agent_notification)
    ticket.destroy
    sla_policy.destroy
    group.destroy
    agent.destroy
    remove_others_redis_key SLA_TICKETS_LIMIT
  end

  def test_sla_reminder_response_trial
    agent = add_agent_to_account(@account, options = { role: 4, active: 1, email: "testxyz@yopmail.com" })
    group = create_group @account
    ticket, sla_policy = create_test_ticket_sla_reminder(agent, group)
    EmailNotification.any_instance.stubs(:agent_notification).returns(true)
    set_others_redis_key(SLA_TICKETS_LIMIT, 2)
    Admin::Sla::Reminder::Trial.new.perform
    ticket.reload
    check_for_correct_response_sla_reminder(ticket, agent)
  ensure
    EmailNotification.any_instance.unstub(:agent_notification)
    ticket.destroy
    sla_policy.destroy
    group.destroy
    agent.destroy
    remove_others_redis_key SLA_TICKETS_LIMIT
  end

  def test_sla_reminder_resolution_trial
    agent = add_agent_to_account(@account, options = { role: 4, active: 1, email: "testxyz@yopmail.com" })
    group = create_group @account
    ticket, sla_policy = create_test_ticket_sla_reminder(agent, group)
    EmailNotification.any_instance.stubs(:agent_notification).returns(true)
    set_others_redis_key(SLA_TICKETS_LIMIT, 2)
    Admin::Sla::Reminder::Trial.new.perform
    ticket.reload
    check_for_correct_resolution_sla_reminder(ticket, agent)
  ensure
    EmailNotification.any_instance.unstub(:agent_notification)
    ticket.destroy
    sla_policy.destroy
    group.destroy
    agent.destroy
    remove_others_redis_key SLA_TICKETS_LIMIT
  end

  def test_sla_reminder_response_free
    agent = add_agent_to_account(@account, options = { role: 4, active: 1, email: "testxyz@yopmail.com" })
    group = create_group @account
    ticket, sla_policy = create_test_ticket_sla_reminder(agent, group)
    EmailNotification.any_instance.stubs(:agent_notification).returns(true)
    set_others_redis_key(SLA_TICKETS_LIMIT, 2)
    Admin::Sla::Reminder::Free.new.perform
    ticket.reload
    check_for_correct_response_sla_reminder(ticket, agent)
  ensure
    EmailNotification.any_instance.unstub(:agent_notification)
    ticket.destroy
    sla_policy.destroy
    group.destroy
    agent.destroy
    remove_others_redis_key SLA_TICKETS_LIMIT
  end

  def test_sla_reminder_resolution_free
    agent = add_agent_to_account(@account, options = { role: 4, active: 1, email: "testxyz@yopmail.com" })
    group = create_group @account
    ticket, sla_policy = create_test_ticket_sla_reminder(agent, group)
    EmailNotification.any_instance.stubs(:agent_notification).returns(true)
    set_others_redis_key(SLA_TICKETS_LIMIT, 2)
    Admin::Sla::Reminder::Free.new.perform
    ticket.reload
    check_for_correct_resolution_sla_reminder(ticket, agent)
  ensure
    EmailNotification.any_instance.unstub(:agent_notification)
    ticket.destroy
    sla_policy.destroy
    group.destroy
    agent.destroy
    remove_others_redis_key SLA_TICKETS_LIMIT
  end

  def test_sla_reminder_response_premium
    agent = add_agent_to_account(@account, options = { role: 4, active: 1, email: "testxyz@yopmail.com" })
    group = create_group @account
    ticket, sla_policy = create_test_ticket_sla_reminder(agent, group)
    EmailNotification.any_instance.stubs(:agent_notification).returns(true)
    set_others_redis_key(SLA_TICKETS_LIMIT, 2)
    Admin::Sla::Reminder::Premium.new.perform
    ticket.reload
    check_for_correct_response_sla_reminder(ticket, agent)
  ensure
    EmailNotification.any_instance.unstub(:agent_notification)
    ticket.destroy
    sla_policy.destroy
    group.destroy
    agent.destroy
    remove_others_redis_key SLA_TICKETS_LIMIT
  end

  def test_sla_reminder_resolution_premium
    agent = add_agent_to_account(@account, options = { role: 4, active: 1, email: "testxyz@yopmail.com" })
    group = create_group @account
    ticket, sla_policy = create_test_ticket_sla_reminder(agent, group)
    EmailNotification.any_instance.stubs(:agent_notification).returns(true)
    set_others_redis_key(SLA_TICKETS_LIMIT, 2)
    Admin::Sla::Reminder::Premium.new.perform
    ticket.reload
    check_for_correct_resolution_sla_reminder(ticket, agent)
  ensure
    EmailNotification.any_instance.unstub(:agent_notification)
    ticket.destroy
    sla_policy.destroy
    group.destroy
    agent.destroy
    remove_others_redis_key SLA_TICKETS_LIMIT
  end

end
