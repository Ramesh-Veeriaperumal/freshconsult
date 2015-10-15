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

  def test_start_time_multiple_errors
    Account.stubs(:current).returns(Account.first)
    tkt = Helpdesk::Ticket.first
    controller_params = { 'timer_running' => false, 'time_spent' => 'sdfdgfd', 'start_time' => '23/12/2001' }
    item = nil
    time_entry = TimeEntryValidation.new(controller_params, item, false)
    time_entry.valid?
    error = time_entry.errors.full_messages
    assert error.include?('Start time timer_running_false')
    Account.unstub(:current)
  end

  def test_start_time_when_timer_running_already
    Account.stubs(:current).returns(Account.first)
    tkt = Helpdesk::Ticket.first
    item = Helpdesk::TimeSheet.new(timer_running: true, user_id: 2)
    controller_params = {start_time: nil}
    time_entry = TimeEntryValidation.new(controller_params, item, true)
    time_entry.valid?(:update)
    error = time_entry.errors.full_messages
    assert error.include?('Start time timer_running_true')
    Account.unstub(:current)
  end

  def test_start_time_when_timer_running_is_false
    Account.stubs(:current).returns(Account.first)
    tkt = Helpdesk::Ticket.first
    controller_params = {start_time: nil, timer_running: false}
    time_entry = TimeEntryValidation.new(controller_params, nil, false)
    time_entry.valid?
    error = time_entry.errors.full_messages
    assert error.include?('Start time timer_running_false')
    Account.unstub(:current)
  end

  def test_agent_id_multiple_errors
    Account.stubs(:current).returns(Account.first)
    tkt = Helpdesk::Ticket.first
    controller_params = { 'timer_running' => false, 'agent_id' => '89', 'start_time' => '23/12/2001' }
    item = Helpdesk::TimeSheet.new(timer_running: true, user_id: 2)
    time_entry = TimeEntryValidation.new(controller_params, item, false)
    time_entry.valid?(:update)
    error = time_entry.errors.full_messages
    assert error.include?('Agent cant_update_user')
    Account.unstub(:current)
  end

  def test_agent_id_when_timer_running
    Account.stubs(:current).returns(Account.first)
    tkt = Helpdesk::Ticket.first
    controller_params = { 'agent_id' => nil }
    item = Helpdesk::TimeSheet.new(timer_running: true, user_id: 2)
    time_entry = TimeEntryValidation.new(controller_params, item, false)
    time_entry.valid?(:update)
    error = time_entry.errors.full_messages
    assert error.include?('Agent cant_update_user')
    Account.unstub(:current)
  end

  def test_billable_does_not_allow_empty_string
    Account.stubs(:current).returns(Account.first)
    tkt = Helpdesk::Ticket.first
    controller_params = { 'billable' => ""}
    item = Helpdesk::TimeSheet.new(timer_running: true, user_id: 2)
    time_entry = TimeEntryValidation.new(controller_params, item, false)
    time_entry.valid?(:update)
    error = time_entry.errors.full_messages
    assert error.include?('Billable data_type_mismatch')
  end

  def test_billable_allows_nil_true_and_false
    Account.stubs(:current).returns(Account.first)
    tkt = Helpdesk::Ticket.first
    item = Helpdesk::TimeSheet.new(timer_running: true, user_id: 2)
    controller_params = {}
    time_entry = TimeEntryValidation.new(controller_params, item, false)
    time_entry.valid?(:update)
    error = time_entry.errors.full_messages
    assert_equal [], error

    controller_params = {billable: true}
    time_entry = TimeEntryValidation.new(controller_params, item, false)
    time_entry.valid?(:update)
    error = time_entry.errors.full_messages
    assert_equal [], error

    controller_params = {billable: false}
    time_entry = TimeEntryValidation.new(controller_params, item, false)
    time_entry.valid?(:update)    
    error = time_entry.errors.full_messages
    assert_equal [], error
  end
end
