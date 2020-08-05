require_relative '../../../test_transactions_fixtures_helper'
require_relative '../../unit_test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper')
require 'sidekiq/testing'
require 'minitest'
require 'webmock/minitest'
Sidekiq::Testing.fake!

require Rails.root.join('test', 'core', 'helpers', 'tickets_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'automation_rules_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'advanced_scope_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'shared_ownership_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'groups_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'controller_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'ticket_fields_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'users_test_helper.rb')

module Admin
  module Observer
    class WorkerTest < ActionView::TestCase
      include CoreTicketsTestHelper
      include CoreUsersTestHelper
      include AccountTestHelper
      include AutomationRulesTestHelper
      include SharedOwnershipTestHelper
      include TicketFieldsTestHelper
      include AdvancedScopeTestHelper
      include UsersTestHelper
      include ControllerTestHelper

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

      def test_add_watcher_condition_with_launchparty
        rule = add_watcher_rule
        ticket = create_ticket
        ticket.created_at = Time.zone.today + 23.hours
        ticket.save
        Account.any_instance.stubs(:ticket_observer_race_condition_fix_enabled?).returns(true)
        ticket.due_by = Time.now.utc + 27.days
        Sidekiq::Testing.inline! { ticket.save }
        ticket = ticket.reload
        assert_equal rule.action_data[0][:value][0], ticket.subscriptions.pluck(:user_id).last
      ensure
        Account.any_instance.unstub(:ticket_observer_race_condition_fix_enabled?)
      end

      def test_irreversible_va_actions_called_in_ticket_after_commit
        add_watcher_rule
        ticket = create_ticket
        ticket.created_at = Time.zone.today + 23.hours # set properties to match conditions
        ticket.save
        Account.any_instance.stubs(:ticket_observer_race_condition_fix_enabled?).returns(true)
        Helpdesk::Ticket.any_instance.stubs(:trigger_va_actions).returns(nil)
        ticket.due_by = Time.now.utc + 27.days # set properties to trigger event
        Sidekiq::Testing.inline! { ticket.save }
        ticket = ticket.reload
        assert_equal nil, ticket.subscriptions.pluck(:user_id).last
      ensure
        Account.any_instance.unstub(:ticket_observer_race_condition_fix_enabled?)
      end

      def test_retry_observer_worker_with_schema_less_locking_exception_with_launch_party
        ticket = create_ticket
        args = {
          doer_id: ticket.id,
          ticket_id: ticket.id,
          current_events: {},
          enqueued_class: 'Helpdesk::Ticket',
          note_id: nil,
          original_attributes: {}
        }
        Account.any_instance.stubs(:ticket_observer_race_condition_fix_enabled?).returns(true)
        Tickets::ObserverWorker.new.perform(args)
        Helpdesk::Ticket.stubs(:find_by_id).returns(ticket)
        ::Tickets::RetryObserverWorker.jobs.clear
        Tickets::ObserverWorker.new.perform(args)
        assert_equal 1, ::Tickets::RetryObserverWorker.jobs.size
      ensure
        Account.any_instance.unstub(:ticket_observer_race_condition_fix_enabled?)
      end

      def test_retry_observer_worker
        ticket = create_ticket
        args = {
          doer_id: ticket.id,
          ticket_id: ticket.id,
          current_events: {},
          enqueued_class: 'Helpdesk::Ticket',
          note_id: nil,
          original_attributes: {}
        }
        mock = Minitest::Mock.new
        mock.expect(:call, true, ["Retrying observer::TicketID::#{args[:ticket_id]}"])
        Rails.logger.stub :info, mock do
          ::Tickets::RetryObserverWorker.new.perform(args)
        end
        mock.verify
      end

      def test_retry_observer_worker_with_schema_less_locking_exception_without_launch_party
        ticket = create_ticket
        args = {
          doer_id: ticket.id,
          ticket_id: ticket.id,
          current_events: {},
          enqueued_class: 'Helpdesk::Ticket',
          note_id: nil,
          original_attributes: {}
        }
        Account.any_instance.stubs(:ticket_observer_race_condition_fix_enabled?).returns(false)
        Tickets::ObserverWorker.new.perform(args)
        Helpdesk::Ticket.stubs(:find_by_id).returns(ticket)
        ::Tickets::RetryObserverWorker.jobs.clear
        Tickets::ObserverWorker.new.perform(args)
        assert_equal 0, ::Tickets::RetryObserverWorker.jobs.size
      ensure
        Account.any_instance.unstub(:ticket_observer_race_condition_fix_enabled?)
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

      def test_parent_child_ticket_observer_adding_notes
        Account.any_instance.stubs(:parent_child_tickets_enabled?).returns(true)
        @agent = add_test_agent(@account, role: Role.where(name: 'Account Administrator').first.id)
        rule = parent_child_ticket_observer_rule
        params = {}
        parent_ticket = create_ticket(params)
        parent_ticket.update_attributes(association_type: 1, subsidiary_tkts_count: 1)
        @agent.make_current
        options = { requester_id: @agent.id, assoc_parent_id: parent_ticket.display_id, subject: "#{params[:subject]}_child_tkt" }
        child_ticket = create_ticket(params.merge(options))
        child_ticket.priority = 3
        Sidekiq::Testing.inline! { child_ticket.save }
        child_ticket = child_ticket.reload
        parent_ticket = parent_ticket.reload
        assert_equal rule.action_data[0][:note_body], parent_ticket.notes.last.note_body.body
        assert_equal rule.action_data[1][:note_body], child_ticket.notes.last.note_body.body
        Tickets::ResetAssociations.new.perform(ticket_ids: [parent_ticket.display_id, child_ticket.display_id])
        Account.any_instance.unstub(:parent_child_tickets_enabled?)
      ensure
        rule.destroy if rule.present?
        child_ticket.destroy if child_ticket.present?
        parent_ticket.destroy if parent_ticket.present?
        User.reset_current_user
        @agent = nil
      end

      def test_observer_exec_for_write_access_tickets
        Account.any_instance.stubs(:advanced_ticket_scopes_enabled?).returns(true)
        rule = Account.current.observer_rules.first
        agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
        agent_group = create_agent_group_with_write_access(Account.current, agent)
        agent.make_current
        events = generate_event('update')
        rule.condition_data = {
          conditions: { all: [] },
          events: events,
          performer: generate_performer(1)
        }
        rule.action_data = ['add_note'].map { |action| generate_action_data(action, false) }
        rule.save
        ticket = create_ticket
        ticket.group_id = agent_group.group_id
        ticket.save!
        trigger_event(ticket, 'update', events)
        Sidekiq::Testing.inline! do
          ticket.save
        end
        ticket = ticket.reload
        assert_equal ticket.notes.last.body, rule.action_data.first[:note_body]
      ensure
        Account.any_instance.unstub(:advanced_ticket_scopes_enabled?)
      end

      def test_observer_skip_for_read_only_tickets
        Account.any_instance.stubs(:advanced_ticket_scopes_enabled?).returns(true)
        rule = Account.current.observer_rules.first
        agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
        agent_group = create_agent_group_with_read_access(Account.current, agent)
        events = generate_event('update')
        rule.condition_data = {
          conditions: { all: [] },
          events: events,
          performer: generate_performer(1)
        }
        rule.action_data = ['add_note'].map { |action| generate_action_data(action, false) }
        rule.save
        ticket = create_ticket
        ticket.group_id = agent_group.group_id
        ticket.save!
        agent.make_current
        trigger_event(ticket, 'update', events)
        Sidekiq::Testing.inline! do
          ticket.save
        end
        ticket = ticket.reload
        assert_not_equal ticket.notes.last.body, rule.action_data.first[:note_body]
      ensure
        Account.any_instance.unstub(:advanced_ticket_scopes_enabled?)
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

        def parent_child_ticket_observer_rule
          rule = @account.observer_rules.new
          rule.name = 'parent_child_test_rule'
          rule.filter_data = []
          rule.condition_data = { performer: { 'type' => '3' }, events: [{ name: 'priority', from: '--', to: '--' }], conditions: { any: [{ evaluate_on: ':ticket', name: 'association_type', operator: 'is', value: 2 }] } }
          rule.action_data = [{ name: 'add_note', note_body: 'adding note in parent', evaluate_on: 'parent_ticket' }, { name: 'add_note', note_body: 'adding note in child', evaluate_on: 'same_ticket' }]
          rule.save!
          rule.reload
          rule
        end

        def create_ticket_for_observer(ticket_params)
          create_ticket(ticket_params)
        end

        def add_watcher_rule
          field_name = 'created_during'
          operator = 'during'
          rule_value = generate_value(:date_time, field_name, false, operator)
          rule = Account.current.observer_rules.first
          condition_data = { all: [{ evaluate_on: 'ticket', name: field_name, operator: operator, value: rule_value }] }
          performer = generate_performer(1)
          events = generate_event('change')
          rule.condition_data = { conditions: condition_data, events: events, performer: performer }
          Account.current.groups.first || create_group(Account.current)
          rule.action_data = ['add_watcher'].map do |action|
            generate_action_data(action, false)
          end
          rule.save
          rule
        end
    end
  end
end
