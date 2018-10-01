require_relative '../../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
['user_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
require Rails.root.join('test', 'api', 'helpers', 'tickets_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'conversations_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'test_case_methods.rb')
require Rails.root.join('test', 'core', 'helpers', 'controller_test_helper.rb')

class ResetAssociationsTest < ActionView::TestCase
  include TicketsTestHelper
  include UsersHelper
  include TestCaseMethods
  include ControllerTestHelper
  include ConversationsTestHelper

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

  def test_reset_associations_for_parent_ticket
    enable_adv_ticketing([:parent_child_tickets]) do
      create_parent_child_tickets
      Tickets::ResetAssociations.new.perform(ticket_ids: [@parent_ticket.display_id])
      @parent_ticket.reload
      @child_ticket.reload
      assert_equal @parent_ticket.association_type, nil
      assert_equal @child_ticket.association_type, nil
    end
  end

  def test_reset_associations_for_child_ticket
    enable_adv_ticketing([:parent_child_tickets]) do
      create_parent_child_tickets
      Tickets::ResetAssociations.new.perform(ticket_ids: [@child_ticket.display_id])
      @child_ticket.reload
      assert_equal @child_ticket.association_type, nil
      assert_equal @child_ticket.associates_rdb, nil
    end
  end

  def test_reset_associations_for_tracker_ticket
    enable_adv_ticketing([:link_tickets]) do
      create_linked_tickets
      create_broadcast_note(@tracker_id)
      Tickets::ResetAssociations.new.perform(ticket_ids: [@tracker_id])
      tracker_ticket = @account.tickets.find_by_display_id(@tracker_id)
      assert_equal tracker_ticket.associates.count, 0
      assert_equal tracker_ticket.notes.broadcast_notes.count, 0
    end
  end

  def test_reset_associations_for_related_ticket
    enable_adv_ticketing([:link_tickets]) do
      create_linked_tickets
      Tickets::ResetAssociations.new.perform(ticket_ids: [@ticket_id])
      related_ticket = @account.tickets.find_by_display_id(@ticket_id)
      assert_equal related_ticket.association_type, nil
      assert_equal related_ticket.associates_rdb, nil
    end
  end

  def test_reset_associations_with_disable_link_tickets
    enable_adv_ticketing([:link_tickets]) do
      create_linked_tickets
      Tickets::ResetAssociations.new.perform(link_feature_disable: true)
      link_tickets = @account.tickets.where(association_type: [3,4])
      assert_equal link_tickets.count, 0
    end
  end

  def test_reset_associations_with_disable_parent_child
    enable_adv_ticketing([:parent_child_tickets]) do
      create_parent_child_tickets
      Tickets::ResetAssociations.new.perform(parent_child_feature_disable: true)
      parent_child_tickets = @account.tickets.where(association_type: [1,2])
      assert_equal parent_child_tickets.count, 0
    end
  end

  def test_reset_associations_with_exception
    assert_raises(RuntimeError) do
      create_parent_child_tickets
      create_linked_tickets
      ticket_ids = [@parent_ticket.display_id, @child_ticket.display_id, @tracker_id, @ticket_id]
      Account.any_instance.stubs(:tickets).raises(RuntimeError)
      Tickets::ResetAssociations.new.perform(ticket_ids: ticket_ids)
      Account.any_instance.unstub(:tickets)
    end
  end
end