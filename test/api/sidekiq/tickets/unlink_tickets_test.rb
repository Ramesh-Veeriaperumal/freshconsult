require_relative '../../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
['user_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
require Rails.root.join('test', 'api', 'helpers', 'tickets_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'controller_test_helper.rb')

class UnlinkTicketsTest < ActionView::TestCase
  include TicketsTestHelper
  include UsersHelper
  include ControllerTestHelper

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

  def test_unlink_multiple_tickets
    tracker_ticket = create_tracker_ticket
    ticket_ids = create_n_tickets(2)
    @account.tickets.where(display_id: ticket_ids).each do |tkt|
      link_to_tracker(tkt, tracker_ticket)
    end
    Tickets::UnlinkTickets.new.perform(related_ticket_ids: ticket_ids)
    related_tickets = @account.tickets.where(display_id: ticket_ids)
    related_tickets.each do |tkt|
      assert_equal tkt.association_type, nil
      assert_equal tkt.associates_rdb, nil
    end
    tracker_ticket.reload
    assert_equal tracker_ticket.subsidiary_tkts_count, 0
  end

  def test_unlink_multiple_tickets_with_exception_handled
    assert_nothing_raised do
      tracker_ticket = create_tracker_ticket
      ticket_ids = create_n_tickets(2)
      @account.tickets.where(display_id: ticket_ids).each do |tkt|
        link_to_tracker(tkt, tracker_ticket)
      end
      Account.any_instance.stubs(:tickets).raises(RuntimeError)
      Tickets::UnlinkTickets.new.perform(related_ticket_ids: ticket_ids)
      Account.any_instance.unstub(:tickets)
      related_tickets = @account.tickets.where(display_id: ticket_ids)
      related_tickets.each do |tkt|
        assert_equal tkt.association_type, TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:related]
        assert_equal tkt.associates_rdb, tracker_ticket.display_id
      end
    end
  end

  def test_unlink_tickets_without_permission
    tracker_ticket = create_tracker_ticket
    ticket_ids = create_n_tickets(2)
    @account.tickets.where(display_id: ticket_ids).each do |tkt|
      link_to_tracker(tkt, tracker_ticket)
    end
    Helpdesk::Ticket.stubs(:find_by_display_id).returns(nil)
    Tickets::UnlinkTickets.new.perform(related_ticket_ids: ticket_ids)
    Helpdesk::Ticket.unstub(:find_by_display_id)
    related_tickets = @account.tickets.where(display_id: ticket_ids)
    related_tickets.each do |tkt|
      assert_equal tkt.association_type, TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:related]
      assert_equal tkt.associates_rdb, tracker_ticket.display_id
    end
  end
end