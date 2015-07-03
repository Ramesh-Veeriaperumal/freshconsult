require_relative '../test_helper'

class TimeSheetValidationsTest < ActionView::TestCase
  def test_ticket_user_numericality
    controller_params = { 'ticket_id' => 'x', 'user_id' => 'x' }
    item = nil
    time_sheet = TimeSheetValidation.new(controller_params, item, Account.first, true)
    time_sheet.valid?(:create)
    error = time_sheet.errors.full_messages
    assert error.include?('Ticket is not a number')
    assert error.include?('User is not a number')
    refute error.include?("Ticket can't be blank")
  end

  def test_ticket_presence
    controller_params = { 'ticket_id' => 999, 'user_id' => 'x' }
    item = nil
    time_sheet = TimeSheetValidation.new(controller_params, item, Account.first, true)
    time_sheet.valid?(:create)
    error = time_sheet.errors.full_messages
    refute error.include?('Ticket is not a number')
    assert error.include?("Ticket can't be blank")
  end

  def test_ticket_presence_valid
    tkt = Helpdesk::Ticket.first
    controller_params = { 'ticket_id' => tkt.display_id, 'user_id' => 'x' }
    item = nil
    time_sheet = TimeSheetValidation.new(controller_params, item, Account.first, true)
    time_sheet.valid?(:create)
    error = time_sheet.errors.full_messages
    refute error.include?("Ticket can't be blank")
    assert_equal tkt, time_sheet.ticket
  end

  def test_start_time_timer_not_running
    tkt = Helpdesk::Ticket.first
    controller_params = { 'ticket_id' => tkt.id, 'timer_running' => false, 'start_time' => Time.zone.now.to_s }
    item = nil
    time_sheet = TimeSheetValidation.new(controller_params, item, Account.first, false)
    time_sheet.valid?
    error = time_sheet.errors.full_messages
    assert error.include?('Start time Should be blank if timer_running is false')
    refute error.include?('User is not a number')
  end
end
