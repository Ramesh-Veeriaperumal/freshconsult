require_relative '../unit_test_helper'

class SolutionArticleFilterValidationTest < ActionView::TestCase
  def setup
    Account.stubs(:current).returns(Account.first)
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_valid
    solution_article_filter = SolutionArticleFilterValidation.new(user_id: 'XYZ', language_id: 6)
    assert !solution_article_filter.valid?
    errors = solution_article_filter.errors.full_messages
    assert errors.include?('User datatype_mismatch')
    solution_article_filter = SolutionArticleFilterValidation.new(user_id: 5, language_id: 6)
    assert solution_article_filter.valid?
  end

  def test_invalid_negative_author_except_minus_one
    SolutionArticleFilterValidation.any_instance.stubs(:validation_context).returns(:filter)
    solution_article_filter = SolutionArticleFilterValidation.new(author: -1000, portal_id: '1', language: 'en')
    assert !solution_article_filter.valid?, 'author should be -1 or greater than 0'
  ensure
    SolutionArticleFilterValidation.any_instance.unstub(:validation_context)
  end

  def test_valid_author_minus_one
    SolutionArticleFilterValidation.any_instance.stubs(:validation_context).returns(:filter)
    solution_article_filter = SolutionArticleFilterValidation.new(author: -1, portal_id: '1', language: 'en')
    assert solution_article_filter.valid?
  ensure
    SolutionArticleFilterValidation.any_instance.unstub(:validation_context)
  end

  def test_valid_author
    SolutionArticleFilterValidation.any_instance.stubs(:validation_context).returns(:filter)
    solution_article_filter = SolutionArticleFilterValidation.new(author: 1, portal_id: '1', language: 'en')
    assert solution_article_filter.valid?, 'author should be -1 or greater than 0'
  ensure
    SolutionArticleFilterValidation.any_instance.unstub(:validation_context)
  end

  def test_invalid_author_zero
    SolutionArticleFilterValidation.any_instance.stubs(:validation_context).returns(:filter)
    solution_article_filter = SolutionArticleFilterValidation.new(author: 0, portal_id: '1', language: 'en')
    assert !solution_article_filter.valid?, 'author should be -1 or greater than 0'
  ensure
    SolutionArticleFilterValidation.any_instance.unstub(:validation_context)
  end

  def test_nil_author
    SolutionArticleFilterValidation.any_instance.stubs(:validation_context).returns(:filter)
    solution_article_filter = SolutionArticleFilterValidation.new(author: nil, portal_id: '1', language: 'en')
    assert !solution_article_filter.valid?, 'author should be -1 or greater than 0'
  ensure
    SolutionArticleFilterValidation.any_instance.unstub(:validation_context)
  end

  def test_invalid_string_author
    SolutionArticleFilterValidation.any_instance.stubs(:validation_context).returns(:filter)
    solution_article_filter = SolutionArticleFilterValidation.new(author: 'abc', portal_id: '1', language: 'en')
    assert !solution_article_filter.valid?, 'author should be -1 or greater than 0'
  ensure
    SolutionArticleFilterValidation.any_instance.unstub(:validation_context)
  end
end
