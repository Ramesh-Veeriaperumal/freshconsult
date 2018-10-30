require_relative '../unit_test_helper'

class SolutionArticleFilterValidationTest < ActionView::TestCase
  def teardown
    Account.unstub(:current)
    super
  end

  def test_valid
    Account.stubs(:current).returns(Account.first)
    solution_article_filter = SolutionArticleFilterValidation.new(user_id: 'XYZ', language_id: 6)
    assert !solution_article_filter.valid?
    errors = solution_article_filter.errors.full_messages
    assert errors.include?('User datatype_mismatch')

    solution_article_filter = SolutionArticleFilterValidation.new(user_id: 5, language_id: 6)
    assert solution_article_filter.valid?
  end
end
