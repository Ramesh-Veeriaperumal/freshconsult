require_relative '../unit_test_helper'

class ActivityFilterValidationTest < ActionView::TestCase
  def tear_down
    Account.unstub(:current)
    super
  end

  def test_valid
    activity_filter = ActivityFilterValidation.new(limit: 10, since_id: 1000, before_id: 2000)
    result = activity_filter.valid?
    assert result
  end

  def test_nil_value
    activity_filter = ActivityFilterValidation.new(limit: nil, since_id: nil, before_id: nil)
    refute activity_filter.valid?
    error = activity_filter.errors.full_messages
    assert error.include?('Limit datatype_mismatch')
    assert error.include?('Since datatype_mismatch')
    assert error.include?('Before datatype_mismatch')
    assert_equal({ limit: { expected_data_type: :'Positive Integer', prepend_msg: :input_received, given_data_type: 'Null' }, since_id: { expected_data_type: :'Positive Integer', prepend_msg: :input_received, given_data_type: 'Null' }, before_id: { expected_data_type: :'Positive Integer', prepend_msg: :input_received, given_data_type: 'Null' } }, activity_filter.error_options)
  end

  def test_negative_value
    activity_filter = ActivityFilterValidation.new(limit: -10, since_id: -2000, before_id: -3000)
    refute activity_filter.valid?
    error = activity_filter.errors.full_messages
    assert error.include?('Limit datatype_mismatch')
    assert error.include?('Since datatype_mismatch')
    assert error.include?('Before datatype_mismatch')
    assert_equal({ limit: { expected_data_type: :'Positive Integer', code: :invalid_value }, since_id: { expected_data_type: :'Positive Integer', code: :invalid_value }, before_id: { expected_data_type: :'Positive Integer', code: :invalid_value } }, activity_filter.error_options)
  end
end
