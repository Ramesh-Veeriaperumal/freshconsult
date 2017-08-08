require_relative '../unit_test_helper'

class SolutionArticleFilterValidationTest < ActionView::TestCase
  def test_valid
    solution_article_filter = SolutionArticleFilterValidation.new(user_id: 'XYZ')
    assert !solution_article_filter.valid?
    errors = solution_article_filter.errors.full_messages
    assert errors.include?('User datatype_mismatch')

    solution_article_filter = SolutionArticleFilterValidation.new(user_id: 5)
    assert solution_article_filter.valid?
  end
end
