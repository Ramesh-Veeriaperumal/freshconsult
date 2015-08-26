require_relative '../test_helper'

class TimeSheetValidationsTest < ActionView::TestCase
  def test_ticket_user_numericality
    Account.stubs(:current).returns(Account.first)
    controller_params = { 'ticket_id' => 'x', 'agent_id' => 'x' }
    item = nil
    time_sheet = TimeSheetValidation.new(controller_params, item, true)
    time_sheet.valid?(:create)
    error = time_sheet.errors.full_messages
    assert error.include?('Ticket is not a number')
    assert error.include?('Agent is not a number')
    refute error.include?("Ticket can't be blank")
    Account.unstub(:current)
  end

  def test_ticket_presence
    Account.stubs(:current).returns(Account.first)
    controller_params = { 'ticket_id' => 999, 'agent_id' => 'x' }
    item = nil
    time_sheet = TimeSheetValidation.new(controller_params, item, true)
    time_sheet.valid?(:create)
    error = time_sheet.errors.full_messages
    refute error.include?('Ticket is not a number')
    assert error.include?("Ticket can't be blank")
    Account.unstub(:current)
  end

  def test_ticket_presence_valid
    Account.stubs(:current).returns(Account.first)
    tkt = Helpdesk::Ticket.first
    controller_params = { 'ticket_id' => tkt.display_id, 'agent_id' => 'x' }
    item = nil
    time_sheet = TimeSheetValidation.new(controller_params, item, true)
    time_sheet.valid?(:create)
    error = time_sheet.errors.full_messages
    refute error.include?("Ticket can't be blank")
    assert_equal tkt, time_sheet.ticket
    Account.unstub(:current)
  end

  def test_start_time_timer_not_running
    Account.stubs(:current).returns(Account.first)
    tkt = Helpdesk::Ticket.first
    controller_params = { 'ticket_id' => tkt.id, 'timer_running' => false, 'start_time' => Time.zone.now.to_s }
    item = nil
    time_sheet = TimeSheetValidation.new(controller_params, item, false)
    time_sheet.valid?
    error = time_sheet.errors.full_messages
    assert error.include?('Start time timer_running_false')
    refute error.include?('User is not a number')
    Account.unstub(:current)
  end
end
