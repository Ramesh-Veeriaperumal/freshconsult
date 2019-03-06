require './test/test_helper'

class TicketMergeTest < ActionView::TestCase

  def setup
    @ticket = Helpdesk::Ticket.last.present? ? Helpdesk::Ticket.last : create_ticket
  end

  def test_perform_catches_exceptions
    TicketMerge.any_instance.stubs(:update_source_tickets).raises(StandardError, "test error")

    assert_nothing_raised do
      ticket_merge = TicketMerge.new(@ticket, @ticket, {})
      ticket_merge.perform
    end

    TicketMerge.any_instance.unstub(:update_source_tickets)
  end

  def test_perform_returns_false_when_catches_exceptions
    TicketMerge.any_instance.stubs(:update_source_tickets).raises(StandardError, "test error")

    assert_nothing_raised do
      ticket_merge = TicketMerge.new(@ticket, @ticket, {})
      result = ticket_merge.perform
      assert result == false
    end

    TicketMerge.any_instance.unstub(:update_source_tickets)
  end
end
