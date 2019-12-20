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

  def test_invalid_integer_status
    SolutionArticleFilterValidation.any_instance.stubs(:validation_context).returns(:filter)
    solution_article_filter = SolutionArticleFilterValidation.new(status: 0, portal_id: '1', language: 'en')
    assert !solution_article_filter.valid?, 'It should be in [1,2,3,4,5]'
  ensure
    SolutionArticleFilterValidation.any_instance.unstub(:validation_context)
  end

  def test_invalid_string_status
    SolutionArticleFilterValidation.any_instance.stubs(:validation_context).returns(:filter)
    solution_article_filter = SolutionArticleFilterValidation.new(status: 'a', portal_id: '1', language: 'en')
    assert !solution_article_filter.valid?, 'It should be in [1,2,3,4,5]'
  ensure
    SolutionArticleFilterValidation.any_instance.unstub(:validation_context)
  end

  def test_valid_status
    SolutionArticleFilterValidation.any_instance.stubs(:validation_context).returns(:filter)
    solution_article_filter = SolutionArticleFilterValidation.new(status: 3, portal_id: '1', language: 'en')
    assert solution_article_filter.valid?, 'It should be in [1,2,3,4,5]'
  ensure
    SolutionArticleFilterValidation.any_instance.unstub(:validation_context)
  end

  def test_invalid_approver_id
    SolutionArticleFilterValidation.any_instance.stubs(:validation_context).returns(:filter)
    solution_article_filter = SolutionArticleFilterValidation.new(approver: 0, status: Solution::ArticleFilterScoper::STATUS_FILTER_BY_TOKEN[:in_review], portal_id: '1', language: 'en')
    assert !solution_article_filter.valid?, 'It should be a/an Positive Integer'
  ensure
    SolutionArticleFilterValidation.any_instance.unstub(:validation_context)
  end

  def test_approver_with_valid_status
    SolutionArticleFilterValidation.any_instance.stubs(:validation_context).returns(:filter)
    solution_article_filter = SolutionArticleFilterValidation.new(approver: 1, status: Solution::ArticleFilterScoper::STATUS_FILTER_BY_TOKEN[:in_review], portal_id: '1', language: 'en')
    assert solution_article_filter.valid?, 'to select approver status should be in_review or approved'
  ensure
    SolutionArticleFilterValidation.any_instance.unstub(:validation_context)
  end

  def test_approver_without_status
    SolutionArticleFilterValidation.any_instance.stubs(:validation_context).returns(:filter)
    solution_article_filter = SolutionArticleFilterValidation.new(approver: 1, portal_id: '1', language: 'en')
    assert !solution_article_filter.valid?, 'to select approver status should be in_review or approved'
  ensure
    SolutionArticleFilterValidation.any_instance.unstub(:validation_context)
  end

  def test_approver_with_status_not_in_approved_or_inreview
    SolutionArticleFilterValidation.any_instance.stubs(:validation_context).returns(:filter)
    solution_article_filter = SolutionArticleFilterValidation.new(approver: 1, status: Solution::ArticleFilterScoper::STATUS_FILTER_BY_TOKEN[:draft], portal_id: '1', language: 'en')
    assert !solution_article_filter.valid?, 'to select approver status should be in_review or approved'
  ensure
    SolutionArticleFilterValidation.any_instance.unstub(:validation_context)
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
