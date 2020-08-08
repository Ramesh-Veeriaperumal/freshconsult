require_relative '../unit_test_helper'

class TopicValidationsTest < ActionView::TestCase
  def test_presence_params_invalid
    controller_params = {}
    item = nil
    topic = ApiDiscussions::TopicValidation.new(controller_params, item)
    refute topic.valid?(:update)
    assert topic.errors.full_messages.include?('Title datatype_mismatch')
    assert topic.errors.full_messages.include?('Message datatype_mismatch')
    assert topic.errors.full_messages.include?('Forum datatype_mismatch')
    assert_equal({ title: {  expected_data_type: String, code: :missing_field  }, message: {  expected_data_type: String, code: :missing_field },
                   forum_id: {  expected_data_type: :'Positive Integer', code: :missing_field } }, topic.error_options)
  end

  def test_numericality_params_invalid
    controller_params = { 'forum_id' => 'x', 'stamp_type' => 'x' }
    item = nil
    topic = ApiDiscussions::TopicValidation.new(controller_params, item)
    refute topic.valid?(:update)
    error = topic.errors.full_messages
    assert error.include?('Forum datatype_mismatch')
    assert error.include?('Stamp type datatype_mismatch')
    assert_equal({ title: { expected_data_type: String, code: :missing_field },
                   message: { expected_data_type: String, code: :missing_field },
                   forum_id: { expected_data_type: :'Positive Integer', prepend_msg: :input_received, given_data_type: String, code: :datatype_mismatch },
                   stamp_type: { expected_data_type: :'Positive Integer', prepend_msg: :input_received, given_data_type: String, code: :datatype_mismatch } }, topic.error_options)
  end

  def test_datatype_params_invalid
    controller_params = { 'message' => true, 'sticky' => nil, 'locked' => nil }
    item = nil
    topic = ApiDiscussions::TopicValidation.new(controller_params, item)
    refute topic.valid?
    error = topic.errors.full_messages
    assert error.include?('Message datatype_mismatch')
    assert error.include?('Sticky datatype_mismatch')
    assert error.include?('Locked datatype_mismatch')
    assert_equal({ title: { expected_data_type: String, code: :missing_field },
                   message: { expected_data_type: String, prepend_msg: :input_received, given_data_type: 'Boolean' },
                   sticky: { expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: 'Null'  },
                   locked: { expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: 'Null'  } }, topic.error_options)
  end

  def test_inclusion_params_invalid
    controller_params = { 'sticky' => false, 'locked' => 'x' }
    item = nil
    topic = ApiDiscussions::TopicValidation.new(controller_params, item)
    refute topic.valid?
    error = topic.errors.full_messages
    assert error.include?('Locked datatype_mismatch')
    refute error.include?('Sticky datatype_mismatch')
    assert_equal({ title: { expected_data_type: String, code: :missing_field },
                   message: { expected_data_type: String, code: :missing_field }, sticky: {},
                   locked: { expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String } }, topic.error_options)
  end

  def test_presence_item_valid
    item = Topic.new(title: 'test')
    post = Post.new
    Post.any_instance.stubs(:body_html).returns('test')
    item.stubs(:first_post).returns(Post.new)
    controller_params = {}
    topic = ApiDiscussions::TopicValidation.new(controller_params, item)
    topic.valid?
    error = topic.errors.full_messages
    refute error.include?('Title blank')
    refute error.include?('Message blank')
    refute error.include?('Title missing')
    refute error.include?('Message missing')
  ensure
    Post.any_instance.unstub(:body_html)
  end

  def test_numericality_item_valid_only_update
    controller_params = {}
    item = Topic.new('user_id' => 2, 'stamp_type' => 2)
    item.forum_id = 0
    topic = ApiDiscussions::TopicValidation.new(controller_params, item)
    refute topic.valid?
    error = topic.errors.full_messages
    refute error.include?('Forum datatype_mismatch')
    refute error.include?('User is not a number')
    refute error.include?('Stamp Type datatype_mismatch')
  end

  def test_inclusion_item_valid
    controller_params = {}
    item = Topic.new('sticky' => 'true', 'locked' => false)
    topic = ApiDiscussions::TopicValidation.new(controller_params, item)
    topic.valid?
    error = topic.errors.full_messages
    refute error.include?('Locked datatype_mismatch')
    refute error.include?('Sticky datatype_mismatch')
  end

  def test_topic_validation_valid_params
    item = Topic.new({})
    params = { 'title' => 'test', 'message' => 'test', 'forum_id' => 1, 'user_id' => 1, 'locked' => false,
               'published' => false, 'sticky' => false }
    topic = ApiDiscussions::TopicValidation.new(params, item)
    assert topic.valid?
  end

  def test_topic_validation_valid_item
    item = Topic.new(title: 'test', user_id: 1, locked: false, published: false, sticky: false)
    item.forum_id = 1
    Post.any_instance.stubs(:body_html).returns('test')
    item.stubs(:first_post).returns(Post.new)
    topic = ApiDiscussions::TopicValidation.new({}, item)
    assert topic.valid?
  ensure
    Post.any_instance.unstub(:body_html)
  end
end
