require_relative '../unit_test_helper'

class MonitorValidationsTest < ActionView::TestCase
  def test_numericality_params_invalid
    controller_params = { 'user_id' => 'x'  }
    monitor = ApiDiscussions::MonitorValidation.new(controller_params, nil, true)
    refute monitor.valid?
    error = monitor.errors.full_messages
    assert error.include?('User is not a number')
  end

  def test_numericality_params_valid
    controller_params = { 'user_id' => '1' }
    monitor = ApiDiscussions::MonitorValidation.new(controller_params, nil, true)
    assert monitor.valid?
  end

  def test_numericality_params_invalid_number
    controller_params = { 'user_id' => '1' }
    monitor = ApiDiscussions::MonitorValidation.new(controller_params, nil, false)
    refute monitor.valid?
    error = monitor.errors.full_messages
    assert error.include?('User datatype_mismatch')
    assert_equal({ user_id: { expected_data_type: :'Positive Integer', prepend_msg: :input_received, given_data_type: String } }, monitor.error_options)
  end

  def test_numericality_params_absent
    controller_params = {}
    monitor = ApiDiscussions::MonitorValidation.new(controller_params)
    assert monitor.valid?
  end
end
