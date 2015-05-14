require_relative '../test_helper'

class ForumValidationsTest < ActionView::TestCase
 
  def test_presence_params_invalid
    controller_params = {}
    item = nil
    forum = ApiDiscussions::ForumValidation.new(controller_params, item)
    refute forum.valid?
    assert_equal ["Name can't be blank", "Forum category is not a number", "Forum visibility is not included in the list", 
      "Forum type is not included in the list"], forum.errors.full_messages
  end

  def test_numericality_params_invalid
    controller_params = {"forum_category_id" => "x"}
    item = nil
    forum = ApiDiscussions::ForumValidation.new(controller_params, item)
    refute forum.valid?
    assert forum.errors.full_messages.include?("Forum category is not a number")
  end

  def test_inclusion_params_invalid
    controller_params = {"forum_type" => "x"}
    item = nil
    forum = ApiDiscussions::ForumValidation.new(controller_params, item)
    refute forum.valid?
    error = forum.errors.full_messages
    assert error.include?("Forum visibility is not included in the list")
    assert error.include?("Forum type is not included in the list")
  end

  def test_presence_item_valid
    controller_params = {}
    item = Forum.new({:name => "test"})
    forum = ApiDiscussions::ForumValidation.new(controller_params, item)
    refute forum.errors.full_messages.include?("Name can't be blank")
  end

  def test_numericality_item_valid
    controller_params = {}
    item = Forum.new
    item.forum_category_id = 2
    forum = ApiDiscussions::ForumValidation.new(controller_params, item)
    refute forum.errors.full_messages.include?("Forum category is not a number")
  end

  def test_inclusion_item_valid
    controller_params = {}
    item = Forum.new({:forum_type => "1", :forum_visibility => 1})
    forum = ApiDiscussions::ForumValidation.new(controller_params, item)
    error = forum.errors.full_messages
    refute error.include?("Forum type is not included in the list")
    refute error.include?("Forum visibility is not included in the list")
  end

  def test_forum_validation_valid_params
    item = Forum.new({})
    params = {"name" => "test", "forum_category_id" => "1", "forum_visibility" => "2", "forum_type" => 1}
    forum = ApiDiscussions::ForumValidation.new(params, item)
    assert forum.valid?
  end

  def test_forum_validation_valid_item
    item = Forum.new({:name => "test", :forum_visibility => "2", :forum_type => 1})
    item.forum_category_id = "1"
    forum = ApiDiscussions::ForumValidation.new({}, item)
    assert forum.valid?
  end
end