require_relative '../unit_test_helper'

class TimeEntryValidationTest < ActionView::TestCase
  def test_user_numericality
    Account.stubs(:current).returns(Account.first)
    controller_params = { 'agent_id' => 'x' }
    item = nil
    time_entry = TimeEntryValidation.new(controller_params, item, true)
    time_entry.valid?(:create)
    error = time_entry.errors.full_messages
    assert error.include?('Agent data_type_mismatch')
    Account.unstub(:current)
  end

  def test_start_time_timer_not_running
    Account.stubs(:current).returns(Account.first)
    tkt = Helpdesk::Ticket.first
    controller_params = { 'timer_running' => false, 'start_time' => Time.zone.now.to_s }
    item = nil
    time_entry = TimeEntryValidation.new(controller_params, item, false)
    time_entry.valid?
    error = time_entry.errors.full_messages
    assert error.include?('Start time timer_running_false')
    refute error.include?('User is not a number')
    Account.unstub(:current)
  end

  def test_invalid_time_spent_minutes
    Account.stubs(:current).returns(Account.first)
    tkt = Helpdesk::Ticket.first
    controller_params = { 'timer_running' => false, 'time_spent' => '89:78' }
    item = nil
    time_entry = TimeEntryValidation.new(controller_params, item, false)
    time_entry.valid?
    error = time_entry.errors.full_messages
    assert error.include?('Time spent invalid_time_spent')
    Account.unstub(:current)
  end

  def test_invalid_time_spent_string
    Account.stubs(:current).returns(Account.first)
    tkt = Helpdesk::Ticket.first
    controller_params = { 'timer_running' => false, 'time_spent' => 'sdfdgfd' }
    item = nil
    time_entry = TimeEntryValidation.new(controller_params, item, false)
    time_entry.valid?
    error = time_entry.errors.full_messages
    assert error.include?('Time spent invalid_time_spent')
    Account.unstub(:current)
  end
end
