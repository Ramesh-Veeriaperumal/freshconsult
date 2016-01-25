require_relative '../unit_test_helper'

class ForumValidationsTest < ActionView::TestCase
  def test_presence_params_invalid
    controller_params = {}
    item = nil
    forum = ApiDiscussions::ForumValidation.new(controller_params, item)
    refute forum.valid?(:update)
    assert_equal ['Name missing', 'Forum category required_and_numericality', 'Forum visibility required_and_inclusion',
                  'Forum type required_and_inclusion'], forum.errors.full_messages
  end

  def test_numericality_params_invalid
    controller_params = { 'forum_category_id' => 'x' }
    item = nil
    forum = ApiDiscussions::ForumValidation.new(controller_params, item)
    refute forum.valid?(:update)
    assert forum.errors.full_messages.include?('Forum category data_type_mismatch')
  end

  def test_inclusion_params_invalid
    controller_params = { 'forum_type' => '1', 'forum_visibility' => '1', 'company_ids' => 'test' }
    item = nil
    forum = ApiDiscussions::ForumValidation.new(controller_params, item)
    refute forum.valid?
    error = forum.errors.full_messages
    assert error.include?('Forum visibility not_included_datatype')
    assert error.include?('Forum type not_included_datatype')
    assert forum.errors[:company_ids].blank?

    controller_params = { 'forum_type' => 'x', 'forum_visibility' => 'x', 'company_ids' => ['test'] }
    item = nil
    forum = ApiDiscussions::ForumValidation.new(controller_params, item)
    refute forum.valid?
    error = forum.errors.full_messages
    assert error.include?('Forum visibility not_included')
    assert error.include?('Forum type not_included')
    assert forum.errors[:company_ids].blank?

    controller_params = { 'forum_type' => true, 'forum_visibility' => true, 'company_ids' => ['test'] }
    item = nil
    forum = ApiDiscussions::ForumValidation.new(controller_params, item)
    refute forum.valid?
    error = forum.errors.full_messages
    assert error.include?('Forum visibility not_included')
    assert error.include?('Forum type not_included')
    assert forum.errors[:company_ids].blank?
  end

  def test_presence_item_valid
    controller_params = {}
    item = Forum.new(name: 'test')
    forum = ApiDiscussions::ForumValidation.new(controller_params, item)
    forum.valid?
    refute forum.errors.full_messages.include?('Name blank')
    refute forum.errors.full_messages.include?('Name missing')
  end

  def test_numericality_item_valid_only_update
    controller_params = {}
    item = Forum.new
    item.forum_category_id = 0
    forum = ApiDiscussions::ForumValidation.new(controller_params, item)
    refute forum.valid?
    refute forum.errors.full_messages.include?('Forum category data_type_mismatch')
  end

  def test_inclusion_item_valid
    controller_params = {}
    item = Forum.new(forum_type: 1, forum_visibility: 1)
    forum = ApiDiscussions::ForumValidation.new(controller_params, item)
    forum.valid?
    error = forum.errors.full_messages
    refute error.include?('Forum type Should be a value in the list 1,2,3,4')
    refute error.include?('Forum visibility Should be a value in the list 1,2,3,4')
  end

  def test_forum_validation_valid_params
    item = Forum.new({})
    params = { 'name' => 'test', 'forum_category_id' => 1, 'forum_visibility' => 2, 'forum_type' => 1 }
    forum = ApiDiscussions::ForumValidation.new(params, item)
    assert forum.valid?
  end

  def test_forum_validation_valid_item
    item = Forum.new(name: 'test', forum_visibility: 2, forum_type: 1)
    item.forum_category_id = 1
    forum = ApiDiscussions::ForumValidation.new({}, item)
    assert forum.valid?
  end

  def test_update_forum_type_invalid
    controller_params = { forum_type: nil }
    item = Forum.new(forum_type: 1, forum_visibility: 1, topics_count: 2, forum_category_id: 1, name: Faker::Name.name)
    item.forum_category_id = 1
    forum = ApiDiscussions::ForumValidation.new(controller_params, item)
    refute forum.valid?(:update)
    assert_equal ['Forum type incompatible_field'], forum.errors.full_messages
  end

  def test_company_ids_invalid
    controller_params = { company_ids: nil }
    item = Forum.new(forum_type: 1, forum_visibility: 1, topics_count: 2, forum_category_id: 1, name: Faker::Name.name)
    item.forum_category_id = 1
    forum = ApiDiscussions::ForumValidation.new(controller_params, item)
    refute forum.valid?(:update)
    assert_equal ['Company ids incompatible_field'], forum.errors.full_messages

    controller_params = { company_ids: 'test' }
    item = Forum.new(forum_type: 1, forum_visibility: 1, topics_count: 2, forum_category_id: 1, name: Faker::Name.name)
    item.forum_category_id = 1
    forum = ApiDiscussions::ForumValidation.new(controller_params, item)
    refute forum.valid?(:update)
    assert_equal ['Company ids incompatible_field'], forum.errors.full_messages

    controller_params = { company_ids: ['test'] }
    item = Forum.new(forum_type: 1, forum_visibility: 1, topics_count: 2, forum_category_id: 1, name: Faker::Name.name)
    item.forum_category_id = 1
    forum = ApiDiscussions::ForumValidation.new(controller_params, item)
    refute forum.valid?(:update)
    assert_equal ['Company ids incompatible_field'], forum.errors.full_messages
  end

  def test_company_ids_data_type_mismatch
    controller_params = { company_ids: nil }
    item = Forum.new(forum_type: 1, forum_visibility: 4, topics_count: 2, forum_category_id: 1, name: Faker::Name.name)
    item.forum_category_id = 1
    forum = ApiDiscussions::ForumValidation.new(controller_params, item)
    refute forum.valid?(:update)
    assert_equal ['Company ids data_type_mismatch'], forum.errors.full_messages
  end
end
