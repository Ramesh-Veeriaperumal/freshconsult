require_relative '../../../test_transactions_fixtures_helper'
require_relative '../../unit_test_helper'
require_relative './observer_worker_test.rb'
require 'sidekiq/testing'
require 'minitest'
Sidekiq::Testing.fake!

require Rails.root.join('test', 'core', 'helpers', 'account_test_helper')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper')
require Rails.root.join('spec', 'support', 'ticket_helper.rb')

module Admin
  module ServiceTaskObserver
    class WorkerTest < ::Admin::Observer::WorkerTest
      include ::TicketHelper
      include ::TicketConstants
      include ::CoreUsersTestHelper
      include ::AccountTestHelper

      def setup
        create_test_account if Account.first.nil?
        Account.stubs(:current).returns(Account.first)
        @account = Account.first
        user = add_test_agent(Account.current, user_role: @account.roles.find_by_name('Account Administrator'))
        user.make_current
        Account.any_instance.stubs(:field_service_management_enabled?).returns(true)
        Account.current.all_service_task_observer_rules.destroy_all
        Helpdesk::Ticket.any_instance.stubs(:set_parent_child_assn).returns(true)
        ::Tickets::ObserverWorker.jobs.clear
        ::Tickets::ServiceTaskObserverWorker.jobs.clear
      end

      def teardown
        Account.current.all_service_task_observer_rules.destroy_all
        Account.unstub(:current)
        Account.any_instance.unstub(:field_service_management_enabled?)
        Helpdesk::Ticket.any_instance.unstub(:set_parent_child_assn)
        super
      end

      def create_observer_rule(condition_data, action_data, service_task_observer_rule = true)
        rule = service_task_observer_rule ? @account.service_task_observer_rules.new : @account.observer_rules.new
        rule.name = Faker::Lorem.characters(10)
        rule.filter_data = []
        rule.condition_data = condition_data
        rule.action_data = action_data
        rule.save!
      end

      def rule_object
        @account.service_task_observer_rules.new
      end

      def create_ticket_for_observer(ticket_params)
        create_service_task_ticket(ticket_params)
      end

      def test_service_task_observer_is_enqueued_on_service_task_update
        pending_status = Helpdesk::Ticketfields::TicketStatus::PENDING
        priority = TicketConstants::PRIORITY_KEYS_BY_TOKEN
        condition_data = { performer: { 'type' => '3' },
                           events: [{ name: 'priority', from: priority[:low], to: priority[:high] }],
                           conditions: { all: [] } }
        action_data = [{ name: 'status', value: pending_status }]
        create_observer_rule(condition_data, action_data)
        service_task = create_service_task_ticket(priority: priority[:low])
        service_task.priority = priority[:high]
        service_task.save!
        assert_equal 0, ::Tickets::ObserverWorker.jobs.size
        assert_equal 1, ::Tickets::ServiceTaskObserverWorker.jobs.size
      ensure
        ::Tickets::ServiceTaskObserverWorker.jobs.clear
      end
    end
  end
end