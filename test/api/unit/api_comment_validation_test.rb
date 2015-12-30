require_relative '../unit_test_helper'

class ApiCommentValidationTest < ActionView::TestCase
  def test_presence_params_invalid
    controller_params = {}
    item = nil
    comment = ApiDiscussions::ApiCommentValidation.new(controller_params, item)
    refute comment.valid?
    assert_equal ['Body html missing'], comment.errors.full_messages
  end

  def test_inclusion_params_invalid
    controller_params = { 'answer' => nil }
    item = Post.new
    topic = mock("topic")
    topic.stubs(:stamp_type).returns(6)
    item.stubs(:topic).returns(topic)
    comment = ApiDiscussions::ApiCommentValidation.new(controller_params, item)
    refute comment.valid?(:update)
    error = comment.errors.full_messages
    assert error.include?('Answer data_type_mismatch')
  end

  def test_presence_item_valid
    Account.stubs(:current).returns(Account.new)
    item = Post.new(body_html: 'test')
    topic = mock("topic")
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
    topic = mock("topic")
    topic.stubs(:stamp_type).returns(nil)
    item.stubs(:topic).returns(topic)
    item.topic_id = 'ewrer'
    comment = ApiDiscussions::ApiCommentValidation.new(controller_params, item)
    refute comment.valid?(:update)
    error = comment.errors.full_messages
    refute error.include?('Topic data_type_mismatch')
    refute error.include?('User is not a number')
    Account.unstub(:current)
  end

  def test_inclusion_item_valid
    controller_params = {}
    item = Post.new('answer' => '1')
    topic = mock("topic")
    topic.stubs(:stamp_type).returns(nil)
    item.stubs(:topic).returns(topic)
    comment = ApiDiscussions::ApiCommentValidation.new(controller_params, item)
    comment.valid?(:update)
    error = comment.errors.full_messages
    refute error.include?('Answer data_type_mismatch')
  end

  def test_answer_is_incompatible
    Account.stubs(:current).returns(Account.new)
    controller_params = {'answer' => true, 'body_html' => 'test'}
    item = Post.new
    topic = mock("topic")
    topic.stubs(:stamp_type).returns(6)
    item.stubs(:topic).returns(topic)
    comment = ApiDiscussions::ApiCommentValidation.new(controller_params, item)
    assert comment.valid?(:update)

    controller_params = {'answer' => 'nil'}
    topic.stubs(:stamp_type).returns(nil)
    item.stubs(:topic).returns(topic)
    comment = ApiDiscussions::ApiCommentValidation.new(controller_params, item)
    refute comment.valid?(:update)
    error = comment.errors.full_messages
    assert error.include?('Answer incompatible_field')
    refute error.include?('Answer data_type_mismatch')
    Account.unstub(:current)
  end

  def test_comment_validation_valid_params
    topic = mock("topic")
    topic.stubs(:stamp_type).returns(nil)
    item = Post.new({})
    item.stubs(:topic).returns(topic)
    params = { 'body_html' => 'test', 'topic_id' => 1, 'user_id' => 1 }
    comment = ApiDiscussions::ApiCommentValidation.new(params, item)
    assert comment.valid?
  end

  def test_comment_validation_valid_item
    Account.stubs(:current).returns(Account.new)
    topic = mock("topic")
    topic.stubs(:stamp_type).returns(nil)
    item = Post.new(body_html: 'test')
    item.stubs(:topic).returns(topic)
    item.topic_id = 1
    comment = ApiDiscussions::ApiCommentValidation.new({}, item)
    assert comment.valid?
    Account.unstub(:current)
  end
end
