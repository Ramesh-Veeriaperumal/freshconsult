require_relative '../unit_test_helper'

class PostValidationTest < ActionView::TestCase
  def test_presence_params_invalid
    controller_params = {}
    item = nil
    post = ApiDiscussions::PostValidation.new(controller_params, item)
    refute post.valid?
    assert_equal ['Body html missing'], post.errors.full_messages
  end

  def test_inclusion_params_invalid
    controller_params = { 'answer' => 'x' }
    item = nil
    post = ApiDiscussions::PostValidation.new(controller_params, item)
    refute post.valid?
    error = post.errors.full_messages
    assert error.include?('Answer data_type_mismatch')
  end

  def test_presence_item_valid
    Account.stubs(:current).returns(Account.new)
    item = Post.new(body_html: 'test')
    controller_params = {}
    post = ApiDiscussions::PostValidation.new(controller_params, item)
    post.valid?
    error = post.errors.full_messages
    refute error.include?("Message html can't be blank")
    Account.unstub(:current)
  end

  def test_numericality_item_valid
    Account.stubs(:current).returns(Account.new)
    controller_params = {}
    item = Post.new('user_id' => 2)
    item.topic_id = 'ewrer'
    topic = ApiDiscussions::PostValidation.new(controller_params, item)
    refute topic.valid?(:update)
    error = topic.errors.full_messages
    refute error.include?('Topic data_type_mismatch')
    refute error.include?('User is not a number')
    Account.unstub(:current)
  end

  def test_inclusion_item_valid
    controller_params = {}
    item = Post.new('answer' => '1')
    topic = ApiDiscussions::PostValidation.new(controller_params, item)
    topic.valid?
    error = topic.errors.full_messages
    refute error.include?('Answer data_type_mismatch')
  end

  def test_post_validation_valid_params
    item = Topic.new({})
    params = { 'body_html' => 'test', 'topic_id' => 1, 'user_id' => 1 }
    topic = ApiDiscussions::PostValidation.new(params, item)
    assert topic.valid?
  end

  def test_post_validation_valid_item
    item = Post.new(body_html: 'test')
    item.topic_id = 1
    topic = ApiDiscussions::PostValidation.new({}, item)
    assert topic.valid?
  end
end
