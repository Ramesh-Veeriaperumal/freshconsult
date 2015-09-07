require_relative '../test_helper'

class TopicValidationsTest < ActionView::TestCase
  def test_presence_params_invalid
    controller_params = {}
    item = nil
    topic = ApiDiscussions::TopicValidation.new(controller_params, item)
    refute topic.valid?(:update)
    assert_equal ['Title missing', 'Message html missing', 'Forum required_and_numericality'], topic.errors.full_messages
  end

  def test_numericality_params_invalid
    controller_params = { 'forum_id' => 'x', 'stamp_type' => 'x' }
    item = nil
    topic = ApiDiscussions::TopicValidation.new(controller_params, item)
    refute topic.valid?(:update)
    error = topic.errors.full_messages
    assert error.include?('Forum data_type_mismatch')
    assert error.include?('Stamp type data_type_mismatch')
  end

  def test_inclusion_params_invalid
    controller_params = { 'sticky' => false, 'locked' => 'x' }
    item = nil
    topic = ApiDiscussions::TopicValidation.new(controller_params, item)
    refute topic.valid?
    error = topic.errors.full_messages
    assert error.include?('Locked data_type_mismatch')
    refute error.include?('Sticky data_type_mismatch')
  end

  def test_presence_item_valid
    item = Topic.new(title: 'test')
    post = mock('post')
    post.stubs(:body_html).returns('test')
    item.stubs(:first_post).returns(post)
    controller_params = {}
    topic = ApiDiscussions::TopicValidation.new(controller_params, item)
    error = topic.errors.full_messages
    refute error.include?("Title can't be blank")
    refute error.include?("Message html can't be blank")
  end

  def test_numericality_item_valid_only_update
    controller_params = {}
    item = Topic.new('user_id' => 2, 'stamp_type' => 2)
    item.forum_id = 0
    topic = ApiDiscussions::TopicValidation.new(controller_params, item)
    refute topic.valid?
    error = topic.errors.full_messages
    refute error.include?('Forum data_type_mismatch')
    refute error.include?('User is not a number')
    refute error.include?('Stamp Type data_type_mismatch')
  end

  def test_inclusion_item_valid
    controller_params = {}
    item = Topic.new('sticky' => 'true', 'locked' => false)
    topic = ApiDiscussions::TopicValidation.new(controller_params, item)
    error = topic.errors.full_messages
    refute error.include?('Locked data_type_mismatch')
    refute error.include?('Sticky data_type_mismatch')
  end

  def test_topic_validation_valid_params
    item = Topic.new({})
    params = { 'title' => 'test', 'message_html' => 'test', 'forum_id' => 1, 'user_id' => 1, 'locked' => false,
               'published' => false, 'sticky' => false }
    topic = ApiDiscussions::TopicValidation.new(params, item)
    assert topic.valid?
  end

  def test_topic_validation_valid_item
    item = Topic.new(title: 'test', user_id: 1, locked: false, published: false, sticky: false)
    item.forum_id = 1
    post = mock('post')
    post.stubs(:body_html).returns('test')
    item.stubs(:first_post).returns(post)
    topic = ApiDiscussions::TopicValidation.new({}, item)
    assert topic.valid?
  end
end
