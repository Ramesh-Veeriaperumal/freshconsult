require_relative '../../test_helper'

class SlaFlowTest < ActionDispatch::IntegrationTest
  include TicketsTestHelper

  def test_sla_calculation_exception_handling
    t = create_ticket
    Sla::Calculation.jobs.clear
    Thread.current[:ticket_sla_calculation_retries] = nil
    Helpdesk::Ticket.any_instance.stubs(:set_dueby).raises(StandardError)
    Helpdesk::Ticket.any_instance.stubs(:skip_dispatcher?).returns(true)
    Helpdesk::Ticket.any_instance.stubs(:execute_observer?).returns(false)
    Helpdesk::Ticket.any_instance.stubs(:observer_will_not_be_enqueued?).returns(true)
    t.priority = 4
    t.save
    TicketConstants::SLA_CALCULATION_MAX_RETRY.times do
      assert_equal 1, Sla::Calculation.jobs.size
      Sla::Calculation.perform_one
    end
    assert_equal 0, Sla::Calculation.jobs.size
  ensure
    Thread.current[:ticket_sla_calculation_retries] = nil
    Helpdesk::Ticket.any_instance.unstub(:set_dueby)
    Helpdesk::Ticket.any_instance.unstub(:skip_dispatcher?)
    Helpdesk::Ticket.any_instance.unstub(:execute_observer?)
    Helpdesk::Ticket.any_instance.unstub(:observer_will_not_be_enqueued?)
  end
end
