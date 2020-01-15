require_relative '../../../test_transactions_fixtures_helper'
require_relative '../../unit_test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper')
require 'sidekiq/testing'
require 'minitest'
Sidekiq::Testing.fake!

require Rails.root.join('test', 'core', 'helpers', 'tickets_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')

module Admin
  module Observer
    class WorkerTest < ActionView::TestCase
      include CoreTicketsTestHelper
      include CoreUsersTestHelper
      include AccountTestHelper

      def setup
        create_test_account if Account.first.nil?
        Account.stubs(:current).returns(Account.first)
        @account = Account.first
      end

      def teardown
        Account.unstub(:current)
        super
      end

      def test_resolution_due_condition_in_observer
        ticket_params = ticket_params_hash.merge(created_at: (Time.zone.now - 2.hours), due_by: 30.minutes.ago.iso8601)
        ticket = create_ticket(ticket_params)
        rule = @account.observer_rules.first
        rule.name = 'check_resolution_due'
        rule.filter_data = []
        rule.condition_data = { performer: { 'type' => '4' }, events: [{ name: 'resolution_due' }], conditions: { any: [{ evaluate_on: :ticket, name: 'priority', operator: 'in', value: [1, 2, 3, 4] }] } }
        rule.action_data = [{ name: 'status', value: 5 }]
        rule.save!
        rule.check_rule_events(nil, ticket, construct_overdue_type_hash('resolution'))
        rule.action_data.each { |action| assert_equal ticket.status, action[:value] }
      end

      def test_response_due_condition_in_observer
        ticket_params = ticket_params_hash.merge(created_at: (Time.zone.now - 2.hours), fr_due_by: 30.minutes.ago.iso8601)
        ticket = create_ticket(ticket_params)
        rule = @account.observer_rules.first
        rule.name = 'check_response_due'
        rule.filter_data = []
        rule.condition_data = { performer: { 'type' => '4' }, events: [{ name: 'response_due' }], conditions: { any: [{ evaluate_on: :ticket, name: 'priority', operator: 'in', value: [1, 2, 3, 4] }] } }
        rule.action_data = [{ name: 'status', value: 5 }]
        rule.save!
        rule.check_rule_events(nil, ticket, construct_overdue_type_hash('response'))
        rule.action_data.each { |action| assert_equal ticket.status, action[:value] }
      end

      def test_next_response_due_condition_in_observer
        ticket_params = ticket_params_hash.merge(created_at: (Time.zone.now - 2.hours), nr_due_by: 30.minutes.ago.iso8601)
        ticket = create_ticket(ticket_params)
        rule = @account.observer_rules.first
        rule.name = 'check_next_response_due'
        rule.filter_data = []
        rule.condition_data = { performer: { 'type' => '4' }, events: [{ name: 'next_response_due' }], conditions: { any: [{ evaluate_on: :ticket, name: 'priority', operator: 'in', value: [1, 2, 3, 4] }] } }
        rule.action_data = [{ name: 'status', value: 5 }]
        rule.save!
        rule.check_rule_events(nil, ticket, construct_overdue_type_hash('next_response'))
        rule.action_data.each { |action| assert_equal ticket.status, action[:value] }
      end

      def test_send_email_to_requester_in_observer
        ticket, rule = send_email_observer_base 'send_email_to_requester'
        rule_event = { name: 'ticket_action', value: 'marked_spam' }
        rule.check_rule_events(User.first, ticket, rule_event)
        act_hash = {
          name: 'send_email_to_group', email_to: User.first.id, email_subject: 'Test Email',
          email_body: '<p dir="ltr">Test Email description</p>'
        }
        assert_equal true, Va::Action.new(
          act_hash: act_hash, va_rule: rule
        ).trigger(act_on: ticket, doer: User.first, triggered_event: { ticket_action: 'marked_Spam' })
      end

      def test_send_email_to_agent_in_observer
        ticket, rule = send_email_observer_base 'send_email_to_agent'
        rule_event = { name: 'ticket_action', value: 'marked_spam' }
        rule.check_rule_events(User.first, ticket, rule_event)
        act_hash = {
          name: 'send_email_to_group', email_to: User.first.id, email_subject: 'Test Email',
          email_body: '<p dir="ltr">Test Email description</p>'
        }
        assert_equal true, Va::Action.new(
          act_hash: act_hash, va_rule: rule
        ).trigger(act_on: ticket, doer: User.first, triggered_event: { ticket_action: 'marked_Spam' })
      end

      def test_send_email_to_group_in_observer
        ticket, rule = send_email_observer_base 'send_email_to_group'
        rule.action_data[0][:email_to] = 4
        rule.save!
        act_hash = {
          name: 'send_email_to_group', email_to: User.first.id, email_subject: 'Test Email',
          email_body: '<p dir="ltr">Test Email description</p>'
        }
        assert_equal true, Va::Action.new(
          act_hash: act_hash, va_rule: rule
        ).trigger(act_on: ticket, doer: User.first, triggered_event: { ticket_action: 'marked_Spam' })
      end

      private

        def construct_overdue_type_hash(overdue_type)
          { "#{overdue_type}_due".to_sym => true }
        end

        # Base method to simulate send email action in observer
        #
        # Params:
        # => +emailing_type+:: Differnt types of observer emailing action. Can be any one of
        # (send_email_to_agent, send_email_to_requester, send_email_to_group)
        #
        # Returns:
        # => Ticket, Rule object
        def send_email_observer_base(emailing_type)
          ticket_params = ticket_params_hash.merge(created_at: (Time.zone.now - 2.hours), nr_due_by: 30.minutes.ago.iso8601)
          ticket = create_ticket(ticket_params)
          # Mark ticket as spam
          ticket.spam = true
          ticket.save!
          rule = @account.observer_rules.first
          rule.name = "check_#{emailing_type}"
          rule.filter_data = []
          rule.condition_data = { performer: { 'type' => '3' }, events: [{ name: 'ticket_action', value: 'marked_spam' }], conditions: { all: [] } }
          rule.action_data = [{ name: emailing_type.to_s, email_to: -2, email_subject: 'Test Email', email_body: '<p dir="ltr">Test Email description</p>' }]
          rule.save!
          [ticket, rule]
        end
    end
  end
end
