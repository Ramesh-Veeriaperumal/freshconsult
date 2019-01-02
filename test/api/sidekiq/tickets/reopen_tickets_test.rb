require_relative '../../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('spec', 'support', 'user_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'tickets_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'controller_test_helper.rb')

class ReopenTicketsTest < ActionView::TestCase
  include ApiTicketsTestHelper
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

  def test_reopen_resloved_ticket
    ticket = create_ticket(status: 4)
    Tickets::ReopenTickets.new.perform(ticket_ids: [ticket.display_id])
    ticket.reload
    assert ticket.status == 2
  end

  def test_reopen_closed_ticket
    ticket = create_ticket(status: 5)
    Tickets::ReopenTickets.new.perform(ticket_ids: [ticket.display_id])
    ticket.reload
    assert ticket.status == 2
  end

  def test_reopen_pending_ticket
    ticket = create_ticket(status: 3)
    Tickets::ReopenTickets.new.perform(ticket_ids: [ticket.display_id])
    ticket.reload
    assert ticket.status == 3
  end

  def test_reopen_multiple_tickets
    ticket_ids = create_n_tickets(3, status: 4)
    Tickets::ReopenTickets.new.perform(ticket_ids: ticket_ids)
    @account.tickets.where(display_id: ticket_ids).each do |ticket|
      ticket.reload
      assert ticket.status == 2
    end
  end

  def test_reopen_pending_and_resolved_tickets
    ticket = create_ticket(status: 3)
    ticket1 = create_ticket(status: 4)
    Tickets::ReopenTickets.new.perform(ticket_ids: [ticket.display_id, ticket1.display_id])
    ticket.reload
    assert ticket.status == 3
    ticket1.reload
    assert ticket1.status == 2
  end

  def test_reopen_ticket_with_exception
    assert_raises(RuntimeError) do
      ticket = create_ticket(status: 4)
      Account.any_instance.stubs(:tickets).raises(RuntimeError)
      Tickets::ReopenTickets.new.perform(ticket_ids: [ticket.display_id])
      Account.any_instance.unstub(:tickets)
      ticket.reload
      assert ticket.status == 4
    end
  end
end
