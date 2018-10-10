require_relative '../../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
['user_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
require Rails.root.join('test', 'api', 'helpers', 'tickets_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'controller_test_helper.rb')

class LinkTicketsTest < ActionView::TestCase
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

  def test_link_multiple_tickets
    tracker_ticket = create_tracker_ticket
    ticket_ids = create_n_tickets(2)
    Helpdesk::Ticket.any_instance.stubs(:manual_publish).returns(nil)
    Tickets::LinkTickets.new.perform(tracker_id: tracker_ticket.display_id, related_ticket_ids: ticket_ids)
    related_tickets = @account.tickets.where(display_id: ticket_ids)
    related_tickets.each do |tkt|
      assert_equal tkt.association_type, TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:related]
      assert_equal tkt.associates_rdb, tracker_ticket.display_id
    end
    tracker_ticket.reload
    assert_equal tracker_ticket.subsidiary_tkts_count, ticket_ids.size
  ensure
    Helpdesk::Ticket.any_instance.unstub(:manual_publish)
  end

  def test_link_multiple_tickets_with_a_deleted_ticket
    tracker_ticket = create_tracker_ticket
    ticket_ids = create_n_tickets(2)
    @account.tickets.find_by_display_id(ticket_ids.last).update_attribute(:deleted, true)
    Helpdesk::Ticket.any_instance.stubs(:manual_publish).returns(nil)
    Tickets::LinkTickets.new.perform(tracker_id: tracker_ticket.display_id, related_ticket_ids: ticket_ids)
    valid_ticket_ids = ticket_ids - [ticket_ids.last]
    related_tickets = @account.tickets.where(display_id: valid_ticket_ids)
    related_tickets.each do |tkt|
      assert_equal tkt.association_type, TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:related]
      assert_equal tkt.associates_rdb, tracker_ticket.display_id
    end
    tracker_ticket.reload
    assert_equal tracker_ticket.subsidiary_tkts_count, valid_ticket_ids.size
  ensure
    Helpdesk::Ticket.any_instance.unstub(:manual_publish)
  end

  def test_link_multiple_tickets_with_exception
    assert_nothing_raised do
      tracker_ticket = create_tracker_ticket
      ticket_ids = create_n_tickets(2)
      Account.any_instance.stubs(:tickets).raises(RuntimeError)
      Tickets::LinkTickets.new.perform(tracker_id: tracker_ticket.display_id, related_ticket_ids: ticket_ids)
      Account.any_instance.unstub(:tickets)
    end
  end
end