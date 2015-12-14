require_relative '../unit_test_helper'

class CommentValidationTest < ActionView::TestCase
  def test_presence_params_invalid
    controller_params = {}
    item = nil
    comment = ApiDiscussions::CommentValidation.new(controller_params, item)
    refute comment.valid?
    assert_equal ['Body html missing'], comment.errors.full_messages
  end

  def test_inclusion_params_invalid
    controller_params = { 'answer' => 'x' }
    item = nil
    comment = ApiDiscussions::CommentValidation.new(controller_params, item)
    refute comment.valid?
    error = comment.errors.full_messages
    assert error.include?('Answer data_type_mismatch')
  end

  def test_presence_item_valid
    Account.stubs(:current).returns(Account.new)
    item = Post.new(body_html: 'test')
    controller_params = {}
    comment = ApiDiscussions::CommentValidation.new(controller_params, item)
    comment.valid?
    error = comment.errors.full_messages
    refute error.include?("Message html can't be blank")
    Account.unstub(:current)
  end

  def test_numericality_item_valid
    Account.stubs(:current).returns(Account.new)
    controller_params = {}
    item = Post.new('user_id' => 2)
    item.topic_id = 'ewrer'
    topic = ApiDiscussions::CommentValidation.new(controller_params, item)
    refute topic.valid?(:update)
    error = topic.errors.full_messages
    refute error.include?('Topic data_type_mismatch')
    refute error.include?('User is not a number')
    Account.unstub(:current)
  end

  def test_inclusion_item_valid
    controller_params = {}
    item = Post.new('answer' => '1')
    topic = ApiDiscussions::CommentValidation.new(controller_params, item)
    topic.valid?
    error = topic.errors.full_messages
    refute error.include?('Answer data_type_mismatch')
  end

  def test_comment_validation_valid_params
    item = Topic.new({})
    params = { 'body_html' => 'test', 'topic_id' => 1, 'user_id' => 1 }
    topic = ApiDiscussions::CommentValidation.new(params, item)
    assert topic.valid?
  end

  def test_comment_validation_valid_item
    Account.stubs(:current).returns(Account.new)
    item = Post.new(body_html: 'test')
    item.topic_id = 1
    topic = ApiDiscussions::CommentValidation.new({}, item)
    assert topic.valid?
    Account.unstub(:current)
  end
end
