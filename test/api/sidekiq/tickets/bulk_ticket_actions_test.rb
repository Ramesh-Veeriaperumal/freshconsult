# frozen_string_literal: true

require_relative '../../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('spec', 'support', 'user_helper.rb')
require Rails.root.join('spec', 'support', 'automations_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'tickets_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'controller_test_helper.rb')

class Tickets::BulkTicketActionsTest < ActionView::TestCase
  include ApiTicketsTestHelper
  include UsersHelper
  include ControllerTestHelper
  include AutomationsHelper

  MISSING_TICKET_ERROR_HASH = { field: 'ticket_id', message: 'ticket missing', code: 'invalid_ticket_id' }.freeze
  PERMISSION_DENIED_ERROR_HASH = { field: 'ticket_id', message: 'no permission to edit ticket', code: 'no_permission' }.freeze
  STANDARD_EXCEPTION_HASH = { message: 'StandardError' }.freeze

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @agent = get_admin
    @agent.make_current
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_bulk_delete_all_success
    User.stubs(:current).returns(@agent)
    ticket_ids = create_n_tickets(3, priority: 2)
    args = { 'action' => :delete, 'bulk_background' => true, 'ids' => ticket_ids }
    bulk_ticket_action_obj = Tickets::BulkTicketActions.new
    bulk_ticket_action_obj.perform(args)
    @account.tickets.where(display_id: ticket_ids).each do |ticket|
      assert_equal true, ticket.deleted
    end
    assert_equal 3, bulk_ticket_action_obj.success_count
    bulk_ticket_action_obj.status_list.each do |status_hash|
      assert_equal true, status_hash[:success]
    end
    User.unstub(:current)
  end

  def test_bulk_delete_all_failure_no_permission
    user = add_new_user(@account)
    User.stubs(:current).returns(user)
    ticket_ids = create_n_tickets(3, priority: 2)
    args = { 'action' => :delete, 'bulk_background' => true, 'ids' => ticket_ids }
    bulk_ticket_action_obj = Tickets::BulkTicketActions.new
    bulk_ticket_action_obj.perform(args)
    @account.tickets.where(display_id: ticket_ids).each do |ticket|
      assert_equal false, ticket.deleted
    end
    assert_equal 0, bulk_ticket_action_obj.success_count
    bulk_ticket_action_obj.status_list.each do |status_hash|
      assert_equal false, status_hash[:success]
      assert_equal PERMISSION_DENIED_ERROR_HASH, status_hash[:error]
    end
    User.unstub(:current)
  end

  def test_bulk_delete_all_partial_success_id_missing
    User.stubs(:current).returns(@agent)
    ticket_ids = create_n_tickets(3, priority: 2)
    final_ticket_ids = ticket_ids
    final_ticket_ids.push(0)
    args = { 'action' => :delete, 'bulk_background' => true, 'ids' => final_ticket_ids }
    bulk_ticket_action_obj = Tickets::BulkTicketActions.new
    bulk_ticket_action_obj.perform(args)
    @account.tickets.where(display_id: ticket_ids).each do |ticket|
      assert_equal true, ticket.deleted
    end
    assert_equal 3, bulk_ticket_action_obj.success_count
    bulk_ticket_action_obj.status_list.each do |status_hash|
      if status_hash[:id].zero?
        assert_equal false, status_hash[:success]
        assert_equal MISSING_TICKET_ERROR_HASH, status_hash[:error]
      else
        assert_equal true, status_hash[:success]
      end
    end
    User.unstub(:current)
  end

  def test_bulk_delete_exception_case
    User.stubs(:current).returns(@agent)
    ticket_ids = create_n_tickets(1, priority: 2)
    args = { 'action' => :delete, 'bulk_background' => true, 'ids' => ticket_ids }
    bulk_ticket_action_obj = Tickets::BulkTicketActions.new
    Helpdesk::TicketBulkActions.stubs(:new).raises(StandardError)
    bulk_ticket_action_obj.perform(args)
    @account.tickets.where(display_id: ticket_ids).each do |ticket|
      assert_equal false, ticket.deleted
    end
    assert_equal 0, bulk_ticket_action_obj.success_count
    bulk_ticket_action_obj.status_list.each do |status_hash|
      assert_equal false, status_hash[:success]
      assert_equal STANDARD_EXCEPTION_HASH, status_hash[:error]
    end
    User.unstub(:current)
  end
end
