require_relative '../../../unit_test_helper'

class SolutionValidationTest < ActionView::TestCase
  def request_params(page, per_page)
    {
      page: page,
      per_page: per_page
    }
  end

  def test_valid
    params = request_params(1, 2)
    solution_validation = Widget::Search::SolutionValidation.new(params, nil, true)
    assert solution_validation.valid?
  end

  def test_create_invalid_page_per_page
    params = request_params(11, 31)
    solution_validation = Widget::Search::SolutionValidation.new(params, nil, true)
    refute solution_validation.valid?
    error = solution_validation.errors.full_messages
    assert_include error, 'Page must be less than or equal to 10'
    assert_include error, 'Per page must be less than or equal to 30'
    assert_equal({
      page: { expected_data_type: :"Positive Integer", max_value: 10, code: :invalid_value },
      per_page: { expected_data_type: :"Positive Integer", max_value: 30, code: :invalid_value }
    }, solution_validation.error_options)
  end
end
