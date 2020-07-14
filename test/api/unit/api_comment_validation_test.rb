require_relative '../unit_test_helper'

class ApiCommentValidationTest < ActionView::TestCase
  def test_presence_params_invalid
    controller_params = {}
    item = nil
    comment = ApiDiscussions::ApiCommentValidation.new(controller_params, item)
    refute comment.valid?
    assert_equal ['Body datatype_mismatch'], comment.errors.full_messages
    assert_equal({ body: { expected_data_type: String, code: :missing_field } }, comment.error_options)
  end

  def test_inclusion_params_invalid
    controller_params = { 'answer' => nil }
    item = Post.new
    topic = mock('topic')
    topic.stubs(:stamp_type).returns(6)
    item.stubs(:topic).returns(topic)
    comment = ApiDiscussions::ApiCommentValidation.new(controller_params, item)
    refute comment.valid?(:update)
    error = comment.errors.full_messages
    assert error.include?('Answer datatype_mismatch')
  end

  def test_presence_item_valid
    Account.stubs(:current).returns(Account.new)
    item = Post.new(body_html: 'test')
    topic = mock('topic')
    topic.stubs(:stamp_type).returns(nil)
    item.stubs(:topic).returns(topic)
    controller_params = {}
    comment = ApiDiscussions::ApiCommentValidation.new(controller_params, item)
    assert comment.valid?
    Account.unstub(:current)
  end

  def test_numericality_item_valid
    Account.stubs(:current).returns(Account.new)
    controller_params = {}
    item = Post.new('user_id' => 2)
    topic = mock('topic')
    topic.stubs(:stamp_type).returns(nil)
    item.stubs(:topic).returns(topic)
    item.topic_id = 'ewrer'
    comment = ApiDiscussions::ApiCommentValidation.new(controller_params, item)
    refute comment.valid?(:update)
    error = comment.errors.full_messages
    refute error.include?('Topic datatype_mismatch')
    refute error.include?('User is not a number')

    Account.unstub(:current)
  end

  def test_inclusion_item_valid
    controller_params = {}
    item = Post.new('answer' => '1')
    topic = mock('topic')
    topic.stubs(:stamp_type).returns(nil)
    item.stubs(:topic).returns(topic)
    comment = ApiDiscussions::ApiCommentValidation.new(controller_params, item)
    comment.valid?(:update)
    error = comment.errors.full_messages
    refute error.include?('Answer datatype_mismatch')
  end

  def test_answer_is_incompatible
    Account.stubs(:current).returns(Account.new)
    controller_params = { 'answer' => true, body: 'test' }
    item = Post.new
    topic = mock('topic')
    topic.stubs(:stamp_type).returns(6)
    item.stubs(:topic).returns(topic)
    comment = ApiDiscussions::ApiCommentValidation.new(controller_params, item)
    assert comment.valid?(:update)

    controller_params = { 'answer' => 'nil', body: 'test' }
    topic.stubs(:stamp_type).returns(nil)
    item.stubs(:topic).returns(topic)
    comment = ApiDiscussions::ApiCommentValidation.new(controller_params, item)
    refute comment.valid?(:update)
    error = comment.errors.full_messages
    assert error.include?('Answer cannot_set_answer')
    refute error.include?('Answer datatype_mismatch')
    assert_equal({ answer: { code: :incompatible_field }, body: {} }, comment.error_options)
    Account.unstub(:current)
  end

  def test_comment_validation_valid_params
    topic = mock('topic')
    topic.stubs(:stamp_type).returns(nil)
    item = Post.new({})
    item.stubs(:topic).returns(topic)
    params = { body: 'test', 'topic_id' => 1, 'user_id' => 1 }
    comment = ApiDiscussions::ApiCommentValidation.new(params, item)
    assert comment.valid?
  end

  def test_comment_validation_valid_item
    Account.stubs(:current).returns(Account.new)
    topic = mock('topic')
    topic.stubs(:stamp_type).returns(nil)
    item = Post.new(body_html: 'test')
    item.stubs(:topic).returns(topic)
    item.topic_id = 1
    comment = ApiDiscussions::ApiCommentValidation.new({}, item)
    assert comment.valid?
    Account.unstub(:current)
  end

  def test_body
    Account.stubs(:current).returns(Account.new)
    controller_params = {}
    item = Post.new('answer' => '1')
    item.body = ''
    item.body_html = 'test'
    topic = mock('topic')
    topic.stubs(:stamp_type).returns(nil)
    item.stubs(:topic).returns(topic)
    comment = ApiDiscussions::ApiCommentValidation.new(controller_params, item)
    comment.valid?(:update)
    refute comment.errors.full_messages.include?('Body blank')

    item.body = 'test'
    item.body_html = ''
    comment = ApiDiscussions::ApiCommentValidation.new(controller_params, item)
    comment.valid?(:update)
    assert comment.errors.full_messages.include?('Body blank')
    Account.unstub(:current)
  end
end
