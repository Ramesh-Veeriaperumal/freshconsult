require_relative '../unit_test_helper'
class TicketNotifierTest < ActiveSupport::TestCase
  def trigger_escalation_test
    begin
      account = Account.first
      ticket = account.tickets.first
      note = account.notes.first
      Helpdesk::TicketNotifier.forward ticket, note
    rescue => e
      return false
    end
    true
  end
end
