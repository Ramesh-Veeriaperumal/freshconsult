# frozen_string_literal: true

require_relative '../../unit_test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper')
require 'sidekiq/testing'
require 'minitest'
Sidekiq::Testing.fake!

require Rails.root.join('test', 'core', 'helpers', 'tickets_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')

module Admin
  class SupervisorWorkerTest < ActionView::TestCase
    include CoreTicketsTestHelper
    include CoreUsersTestHelper

    def setup
      create_test_account if Account.first.nil?
      Account.stubs(:current).returns(Account.first)
      @account = Account.first
    end

    def teardown
      Account.unstub(:current)
      super
    end

    def test_retry_supervisor_ticket_actions_worker_with_schema_less_locking_exception_without_launch_party
      ticket = create_ticket
      rule = Account.current.supervisor_rules.first
      Account.any_instance.stubs(:retry_ticket_supervisor_actions_enabled?).returns(false)
      slt = ticket.schema_less_ticket
      ticket = Account.current.tickets.last
      ticket.ticket_states.resolved_at = 1.month.ago
      ticket.ticket_states.save!
      ticket.status = 4
      ticket.save!
      ticket.schema_less_ticket.save!
      ticket.stubs(:schema_less_ticket).returns(slt)
      ::Tickets::RetryTicketSupervisorActionsWorker.jobs.clear
      Admin::SupervisorWorker.new.send(:execute_actions, rule, ticket)
      assert_equal 0, ::Tickets::RetryTicketSupervisorActionsWorker.jobs.size
    ensure
      Account.any_instance.unstub(:retry_ticket_supervisor_actions_enabled?)
      ticket.unstub(:schema_less_ticket)
    end

    def test_retry_supervisor_ticket_actions_worker_with_schema_less_locking_exception_with_launch_party
      ticket = create_ticket
      rule = Account.current.supervisor_rules.first
      Account.any_instance.stubs(:retry_ticket_supervisor_actions_enabled?).returns(true)
      slt = ticket.schema_less_ticket
      ticket = Account.current.tickets.last
      ticket.ticket_states.resolved_at = 1.month.ago
      ticket.ticket_states.save!
      ticket.status = 4
      ticket.save!
      ticket.schema_less_ticket.save!
      ticket.stubs(:schema_less_ticket).returns(slt)
      ::Tickets::RetryTicketSupervisorActionsWorker.jobs.clear
      Admin::SupervisorWorker.new.send(:execute_actions, rule, ticket)
      assert_equal 1, ::Tickets::RetryTicketSupervisorActionsWorker.jobs.size
    ensure
      Account.any_instance.unstub(:retry_ticket_supervisor_actions_enabled?)
      ticket.unstub(:schema_less_ticket)
    end
  end
end
