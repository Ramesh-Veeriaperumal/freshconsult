require_relative '../../../test_transactions_fixtures_helper'
require_relative '../../unit_test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper')
require 'sidekiq/testing'
require 'minitest'
Sidekiq::Testing.fake!

require Rails.root.join('test', 'core', 'helpers', 'tickets_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'automation_rules_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'shared_ownership_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'groups_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'ticket_fields_test_helper.rb')

module Admin
  module Observer
    class WorkerTest < ActionView::TestCase
      include CoreTicketsTestHelper
      include CoreUsersTestHelper
      include AccountTestHelper
      include AutomationRulesTestHelper
      include SharedOwnershipTestHelper
      include TicketFieldsTestHelper

      CUSTOM_FIELD_TYPES = [:checkbox, :number, :decimal, :nested_field, :date]

      def setup
        create_test_account if Account.first.nil?
        Account.stubs(:current).returns(Account.first)
        @account = Account.first
        @account.launch :automation_revamp
      end

      def teardown
        Account.unstub(:current)
        @account.rollback :automation_revamp
        super
      end

      # 2.times do
      #   if Account.first.observer_race_condition_fix_enabled?
      #     Account.first.rollback(:observer_race_condition_fix)
      #     feature = "without_observer_race_condition_fix"
      #   else
      #     Account.first.launch(:observer_race_condition_fix)
      #     feature = "with_observer_race_condition_fix"
      #   end
        FIELD_OPERATOR_MAPPING.each do |operator_type, options|
          options[:fields].each do |field_name|
            options[:operators].each do |operator|
              define_method "test_observer_condition_#{field_name}_#{operator}" do
                Rails.logger.debug "start test_observer_condition_#{field_name}_#{operator}"
                Account.current.launch :automation_revamp
                Account.current.add_feature :shared_ownership
                initialize_internal_agent_with_default_internal_group
                if CUSTOM_FIELD_TYPES.include?(operator_type)
                  field = @account.ticket_fields.find_by_field_type("custom_#{operator_type.to_s}")
                  unless field
                    field = operator_type == :nested_field ?
                              create_dependent_custom_field(%w(test_custom_country test_custom_state test_custom_city)) :
                              create_custom_field(Faker::Lorem.characters(9), operator_type.to_s)
                  end
                  field_name = field.name
                end

                not_operator = operator.include?('not')
                rule_value = generate_value(operator_type, field_name, false, operator)
                rule = Account.current.observer_rules.first
                condition_data = { all: [ 
                  { evaluate_on: "ticket", 
                    name: field_name, 
                    operator: operator, 
                    value: rule_value}]
                }
                if operator_type == :nested_field && operator == "is"
                  nested_rules = []
                  field.child_levels.each do |child_field|
                    nested_rules << {
                      name: child_field.name,
                      value: generate_value(operator_type, child_field.name, false, operator),
                      operator: operator
                    }
                  end
                  condition_data[:all].first.merge!({ nested_rules: nested_rules })
                end
                performer = generate_performer(options[:performer])
                events = generate_event(options[:event])
                rule.condition_data = {
                  conditions: condition_data,
                  events: events,
                  performer: performer
                }
                group = Account.current.groups.first || create_group(Account.current)
                rule.action_data = options[:actions].map do |action|
                  generate_action_data(action, not_operator)
                end
                rule.save


                ticket = create_ticket
                ticket_value = generate_value(operator_type, field_name, false) if ["greater_than", "less_than"].include?(operator)
                ticket_value = not_operator ? generate_value(operator_type, field_name, true) : rule_value unless ticket_value
                ticket_value = ticket_value.first if ticket_value.is_a?(Array) && operator == 'is_any_of'
                ticket_params = generate_ticket_params(field_name, ticket_value)
                [*ticket_params].each do |k, v|
                  case k
                  when :cc_emails
                    ticket.cc_email = { tkt_cc: [v] }
                  when :to_email
                    ticket.to_emails = [v]
                  else
                    ticket.send("#{k}=", v) # setting properties to the ticket to match conditions
                  end
                end
                ticket.save


                trigger_event(ticket, options[:event], events)
                Sidekiq::Testing.inline! { ticket.save } # updating ticket and triggering observer

                ticket = ticket.reload
                rule.action_data.each do |action|
                  verify_action_data(action, ticket, not_operator)
                end
                Rails.logger.debug "end test_observer_condition_#{field_name}_#{operator}"
              end
            end
          end
        end
      # end

      def trigger_event(ticket, event_type, events)
        case event_type
        when "update"
          ticket.update_column(:priority, events.first[:from])
          ticket = ticket.reload
          ticket.priority = events.first[:to]
        when "agent"
          ticket.update_column(:responder_id, events.first[:from])
          ticket = ticket.reload
          ticket.responder_id = events.first[:to]
        when "value"
          
        when "change"
          ticket.due_by = Time.now.utc + 27.days
        when "nested_field"

        end
      end

      def rule_object
        @account.observer_rules.first
      end

      def test_resolution_due_condition_in_observer
        ticket_params = ticket_params_hash.merge(created_at: (Time.zone.now - 2.hours), due_by: 30.minutes.ago.iso8601)
        ticket = create_ticket_for_observer(ticket_params)
        rule = rule_object
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
        ticket = create_ticket_for_observer(ticket_params)
        rule = rule_object
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
        ticket = create_ticket_for_observer(ticket_params)
        rule = rule_object
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

      def test_textile_to_html_conversion_in_send_email_observer
        ticket, rule = send_email_observer_base('send_email_to_agent')
        rule.action_data[0][:email_body] = '<div data-identifyelement="277" dir="ltr">{% if ticket.company %}</div><ul><li dir="ltr">With Company</li></ul><p dir="ltr">{% else %}</p><ul><li dir="ltr">Without company</li></ul><p dir="ltr">{% endif %}</p>'
        rule.save!
        act_hash = {
          name: 'send_email_to_group', email_to: User.first.id, email_subject: rule.action_data[0][:email_subject],
          email_body: rule.action_data[0][:email_body]
        }
        assert Va::Action.new(act_hash: act_hash, va_rule: rule).trigger(act_on: ticket, doer: User.first, triggered_event: { ticket_action: 'marked_Spam' })
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
          ticket = create_ticket_for_observer(ticket_params)
          # Mark ticket as spam
          ticket.spam = true
          ticket.save!
          rule = rule_object
          rule.name = "check_#{emailing_type}"
          rule.filter_data = []
          rule.condition_data = { performer: { 'type' => '3' }, events: [{ name: 'ticket_action', value: 'marked_spam' }], conditions: { all: [] } }
          rule.action_data = [{ name: emailing_type.to_s, email_to: -2, email_subject: 'Test Email', email_body: '<p dir="ltr">Test Email description</p>' }]
          rule.save!
          [ticket, rule]
        end

        def create_ticket_for_observer(ticket_params)
          create_ticket(ticket_params)
        end
    end
  end
end
