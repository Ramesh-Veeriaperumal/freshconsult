require_relative '../unit_test_helper'

class FilterValidationTest < ActionView::TestCase
  def test_valid
    filter = FilterValidation.new(page: 1, per_page: 2)
    assert filter.valid?
  end

  def test_nil
    filter = FilterValidation.new(page: nil, per_page: nil)
    refute filter.valid?
    error = filter.errors.full_messages
    assert error.include?('Page datatype_mismatch')
    assert error.include?('Per page per_page_invalid')
    assert_equal({ page: { expected_data_type: :"Positive Integer", prepend_msg: :input_received, given_data_type: 'Null Type' },
                   per_page: { expected_data_type: :"Positive Integer", prepend_msg: :input_received, given_data_type: 'Null Type', max_value: 100 } }, filter.error_options)
  end
end
