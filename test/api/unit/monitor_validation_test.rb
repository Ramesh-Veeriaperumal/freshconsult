require_relative '../unit_test_helper'

class MonitorValidationsTest < ActionView::TestCase
  def test_numericality_params_invalid
    controller_params = { 'user_id' => 'x', 'string_param' => true  }
    monitor = ApiDiscussions::MonitorValidation.new(controller_params)
    refute monitor.valid?
    error = monitor.errors.full_messages
    assert error.include?('User is not a number')
  end

  def test_numericality_params_valid
    controller_params = { 'user_id' => '1', 'string_param' => true }
    monitor = ApiDiscussions::MonitorValidation.new(controller_params)
    assert monitor.valid?
  end

  def test_numericality_params_invalid_number
    controller_params = { 'user_id' => '1', 'string_param' => false }
    monitor = ApiDiscussions::MonitorValidation.new(controller_params)
    refute monitor.valid?
    error = monitor.errors.full_messages
    assert error.include?('User data_type_mismatch')
  end

  def test_numericality_params_absent
    controller_params = {}
    monitor = ApiDiscussions::MonitorValidation.new(controller_params)
    assert monitor.valid?
  end
end
