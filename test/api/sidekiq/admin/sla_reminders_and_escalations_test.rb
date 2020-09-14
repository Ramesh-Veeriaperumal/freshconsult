require_relative '../../../test_transactions_fixtures_helper'
require_relative '../../test_helper'
['users_test_helper', 'groups_test_helper.rb', 'tickets_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }
['sla_policies_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }
require 'sidekiq/testing'
require 'minitest'
Sidekiq::Testing.fake!

class SlaReminderEscalationWorkerTest < ActionView::TestCase
  include CoreUsersTestHelper
  include GroupsTestHelper
  include CoreTicketsTestHelper
  include SlaPoliciesTestHelper
  include Redis::RedisKeys
  include Redis::OthersRedis

  def setup
    create_test_account if Account.first.nil?
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    EmailNotification.any_instance.stubs(:agent_notification).returns(true)
    Subscription.any_instance.stubs(:switch_annual_notification_eligible?).returns(false)
  end

  def teardown
    EmailNotification.any_instance.unstub(:agent_notification)
    Subscription.any_instance.unstub(:switch_annual_notification_eligible?)
    Account.unstub(:current)
    super
  end

  def test_response_reminder
    user = add_agent(@account)
    group = create_group @account
    escalation_action = { reminder_response: {
                          "1" => { :time => -1800, :agents_id => [user.id] || [-1] }
                        }}
    ticket, sla_policy = create_test_ticket_with_sla(user, group, escalation_action)
    ticket.update_attributes(frDueBy: Time.zone.now - 1.hour)
    Admin::Sla::Reminder::Base.any_instance.stubs(:tickets_limit_check).returns(false)
    Admin::Sla::Reminder::Base.new.perform
    ticket.reload
    fr_reminder = @account.email_notifications.response_sla_reminder.first
    check_response(EmailNotification::RESPONSE_SLA_REMINDER, fr_reminder, ticket, user, 'sla_response_reminded')
  ensure
    ticket.destroy
    sla_policy.destroy
    group.destroy
    user.destroy
    Admin::Sla::Reminder::Base.any_instance.unstub(:tickets_limit_check)
  end

  def test_resolution_reminder
    user = add_agent(@account)
    group = create_group @account
    escalation_action = { reminder_resolution: {
                          "1" => { :time => -1800, :agents_id => [user.id] || [-1] }
                        }}
    ticket, sla_policy = create_test_ticket_with_sla(user, group, escalation_action)
    ticket.update_attributes(due_by: Time.zone.now - 1.hour)
    Admin::Sla::Reminder::Base.any_instance.stubs(:tickets_limit_check).returns(false)
    Admin::Sla::Reminder::Base.new.perform
    ticket.reload
    resolution_reminder = @account.email_notifications.resolution_sla_reminder.first
    check_response(EmailNotification::RESOLUTION_SLA_REMINDER, resolution_reminder, ticket, user, 'sla_resolution_reminded')
  ensure
    ticket.destroy
    sla_policy.destroy
    group.destroy
    user.destroy
    Admin::Sla::Reminder::Base.any_instance.unstub(:tickets_limit_check)
  end

  def test_next_response_reminder
    @account.add_feature(:next_response_sla)
    user = add_agent(@account)
    group = create_group @account
    escalation_action = { reminder_next_response: {
                          "1" => { :time => -1800, :agents_id => [user.id] || [-1] }
                        }}
    ticket, sla_policy = create_test_ticket_with_sla(user, group, escalation_action)
    ticket.update_attributes(nr_due_by: Time.zone.now - 1.hour)
    Admin::Sla::Reminder::Base.any_instance.stubs(:tickets_limit_check).returns(false)
    Admin::Sla::Reminder::Base.new.perform
    ticket.reload
    nr_reminder = @account.email_notifications.next_response_sla_reminder.first
    check_response(EmailNotification::NEXT_RESPONSE_SLA_REMINDER, nr_reminder, ticket, user, 'nr_reminded')
  ensure
    @account.revoke_feature(:next_response_sla)
    ticket.destroy
    sla_policy.destroy
    group.destroy
    user.destroy
    Admin::Sla::Reminder::Base.any_instance.unstub(:tickets_limit_check)
  end

  def test_response_escalation
    user = add_agent(@account)
    group = create_group @account
    escalation_action = { response: {
                          "1" => { :time => 1800, :agents_id => [user.id] || [-1] }
                        }}
    ticket, sla_policy = create_test_ticket_with_sla(user, group, escalation_action)
    ticket.update_attributes(frDueBy: Time.zone.now - 1.hour)
    set_others_redis_key(SLA_TICKETS_LIMIT, 1)
    Admin::Sla::Escalation::Base.new.perform
    ticket.reload
    fr_escalation = @account.email_notifications.find_by_notification_type(EmailNotification::FIRST_RESPONSE_SLA_VIOLATION)
    check_response(EmailNotification::FIRST_RESPONSE_SLA_VIOLATION, fr_escalation, ticket, user, 'fr_escalated')
  ensure
    ticket.destroy
    sla_policy.destroy
    group.destroy
    user.destroy
    remove_others_redis_key SLA_TICKETS_LIMIT
  end

  def test_resolution_escalation
    user = add_agent(@account)
    group = create_group @account
    escalation_action = { resolution: {
                          "1" => { :time => 1800, :agents_id => [user.id] || [-1] },
                          "2" => { :time => 2400, :agents_id => [user.id] || [-1] }
                        }}
    ticket, sla_policy = create_test_ticket_with_sla(user, group, escalation_action)
    ticket.update_attributes(due_by: Time.zone.now - 1.hour)
    set_others_redis_key(SLA_TICKETS_LIMIT, 1)
    Admin::Sla::Escalation::Base.new.perform
    ticket.reload
    resolution_escalation = @account.email_notifications.find_by_notification_type(EmailNotification::RESOLUTION_TIME_SLA_VIOLATION)
    check_response(EmailNotification::RESOLUTION_TIME_SLA_VIOLATION, resolution_escalation, ticket, user, 'isescalated')
  ensure
    ticket.destroy
    sla_policy.destroy
    group.destroy
    user.destroy
    remove_others_redis_key SLA_TICKETS_LIMIT
  end

  def test_next_response_escalation
    @account.add_feature(:next_response_sla)
    user = add_agent(@account)
    group = create_group @account
    escalation_action = { next_response: {
                          "1" => { :time => 1800, :agents_id => [user.id] || [-1] }
                        }}
    ticket, sla_policy = create_test_ticket_with_sla(user, group, escalation_action)
    ticket.update_attributes(nr_due_by: Time.zone.now - 1.hour)
    set_others_redis_key(SLA_TICKETS_LIMIT, 1)
    Admin::Sla::Escalation::Base.new.perform
    ticket.reload
    nr_escalation = @account.email_notifications.find_by_notification_type(EmailNotification::NEXT_RESPONSE_SLA_VIOLATION)
    check_response(EmailNotification::NEXT_RESPONSE_SLA_VIOLATION, nr_escalation, ticket, user, 'nr_escalated')
  ensure
    @account.revoke_feature(:next_response_sla)
    ticket&.destroy
    sla_policy&.destroy
    group&.destroy
    user&.destroy
    remove_others_redis_key SLA_TICKETS_LIMIT
  end

  def create_test_ticket_with_sla(user, group, escalation_action)
    ticket = create_ticket(params = { requester_id: user.id, created_at: (Time.zone.now - 2.hours), priority: 4, subject: Faker::Lorem.words(2).join(" ")}, group)
    sla_policy = create_sla_policy_with_details(conditions = {group_id: [group.id]}, escalations = {action: escalation_action}, )
    ticket.schema_less_ticket.update_attributes(long_tc01: sla_policy.id)
    [ticket, sla_policy]
  end

  def check_response(notification, notification_template, ticket, user, check_field)
    mail_message = SlaNotifier.group_escalation(ticket, [user.id], notification)
    exp_subject = Liquid::Template.parse(notification_template.agent_subject_template).render(
                                'ticket' => ticket, 'helpdesk_name' => ticket.account.helpdesk_name)
    assert_equal mail_message.subject, exp_subject
    assert mail_message.part.first.body.decoded.include?('Ticket Details:')
    assert_equal true, ticket.safe_send(check_field)
  end
end
