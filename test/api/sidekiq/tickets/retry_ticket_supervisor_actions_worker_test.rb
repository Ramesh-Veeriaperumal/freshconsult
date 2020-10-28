# frozen_string_literal: true

require_relative '../../unit_test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper')
require 'sidekiq/testing'
require 'minitest'
Sidekiq::Testing.fake!

require Rails.root.join('test', 'core', 'helpers', 'tickets_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')

module Tickets
  class RetryTicketSupervisorActionsWorkerTest < ActionView::TestCase
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

    def test_retry_ticket_supervisor_actions_worker
      ticket = create_ticket
      rule = Account.current.supervisor_rules.first
      rule.action_data = [{ name: 'status', value: 5 }]
      rule.condition_data = [{:name=>"status", :operator=>"is", :value=>4}]
      rule.filter_data = [{:name=>"status", :operator=>"is", :value=>4}]
      rule.save!
      Account.any_instance.stubs(:retry_ticket_supervisor_actions_enabled?).returns(false)
      ticket = Account.current.tickets.last
      ticket.ticket_states.resolved_at = 1.month.ago
      ticket.ticket_states.save!
      ticket.status = 4
      ticket.save!
      Tickets::RetryTicketSupervisorActionsWorker.new.perform(ticket_id: ticket.id, rule_id: rule.id)
      ticket.reload
      assert_equal ticket.status, 5
    ensure
      Account.any_instance.unstub(:retry_ticket_supervisor_actions_enabled?)
    end

    def test_retry_ticket_supervisor_actions_worker_with_non_matching_rule
      ticket = create_ticket
      rule = Account.current.supervisor_rules.first
      rule.action_data = [{ name: 'status', value: 4 }]
      rule.condition_data = [{:name=>"status", :operator=>"is", :value=>5}]
      rule.filter_data = [{:name=>"status", :operator=>"is", :value=>5}]
      rule.save!
      Account.any_instance.stubs(:retry_ticket_supervisor_actions_enabled?).returns(false)
      ticket = Account.current.tickets.last
      ticket.ticket_states.resolved_at = 1.month.ago
      ticket.ticket_states.save!
      ticket.status = 4
      ticket.save!
      Tickets::RetryTicketSupervisorActionsWorker.new.perform(ticket_id: ticket.id, rule_id: rule.id)
      ticket.reload
      assert_equal ticket.status, 4
    ensure
      Account.any_instance.unstub(:retry_ticket_supervisor_actions_enabled?)
    end

    def test_retry_ticket_supervisor_actions_worker_with_exception
      ticket = create_ticket
      rule = Account.current.supervisor_rules.first
      rule.action_data = [{ name: 'status', value: 5 }]
      rule.condition_data = [{:name=>"status", :operator=>"is", :value=>4}]
      rule.filter_data = [{:name=>"status", :operator=>"is", :value=>4}]
      rule.save!
      Account.any_instance.stubs(:retry_ticket_supervisor_actions_enabled?).returns(false)
      Tickets::RetryTicketSupervisorActionsWorker.any_instance.stubs(:can_be_retried?).raises(StandardError)
      ticket = Account.current.tickets.last
      ticket.ticket_states.resolved_at = 1.month.ago
      ticket.ticket_states.save!
      ticket.status = 4
      ticket.save!
      Tickets::RetryTicketSupervisorActionsWorker.new.perform(ticket_id: ticket.id, rule_id: rule.id)
      ticket.reload
      assert_equal ticket.status, 4
    ensure
      Account.any_instance.unstub(:retry_ticket_supervisor_actions_enabled?)
      Tickets::RetryTicketSupervisorActionsWorker.any_instance.unstub(:can_be_retried?)
    end
  end
end
