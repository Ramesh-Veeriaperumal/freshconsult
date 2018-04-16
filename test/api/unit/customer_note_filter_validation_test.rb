require_relative '../unit_test_helper'

class CustomerNoteFilterValidationTest < ActionView::TestCase
  def test_valid
    filter = CustomerNoteFilterValidation.new(page: 1, per_page: 2, next_id: 2)
    assert filter.valid?
  end

  def test_nil
    filter = CustomerNoteFilterValidation.new(next_id: nil)
    refute filter.valid?
    error = filter.errors.full_messages
    assert error.include?('Next datatype_mismatch')
    assert_equal({
      next_id: { expected_data_type: :'Positive Integer', prepend_msg: :input_received, given_data_type: 'Null', code: :datatype_mismatch }
    }, filter.error_options)
  end

  def test_id_negative
    filter = CustomerNoteFilterValidation.new(next_id: -1)
    refute filter.valid?
    error = filter.errors.full_messages
    assert error.include?('Next datatype_mismatch')
    assert_equal({
      next_id: { expected_data_type: :'Positive Integer', code: :invalid_value }
    }, filter.error_options)
  end
end
