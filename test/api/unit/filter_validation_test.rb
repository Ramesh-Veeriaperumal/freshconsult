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
    assert error.include?('Page data_type_mismatch')
    assert error.include?('Per page data_type_mismatch')
  end
end
