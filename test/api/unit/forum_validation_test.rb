require_relative '../unit_test_helper'

class ForumValidationTest < ActionView::TestCase
  def test_presence_params_invalid
    controller_params = {}
    item = nil
    forum = ApiDiscussions::ForumValidation.new(controller_params, item)
    refute forum.valid?(:update)
    assert forum.errors.full_messages.include?('Name datatype_mismatch')
    assert forum.errors.full_messages.include?('Forum category datatype_mismatch')
    assert forum.errors.full_messages.include?('Forum visibility not_included')
    assert forum.errors.full_messages.include?('Forum type not_included')
    assert_equal({ name: {  expected_data_type: String, code: :missing_field }, forum_category_id: {  expected_data_type: :'Positive Integer',
                                                                                                      code: :missing_field }, forum_visibility: { list: '1,2,3,4', code: :missing_field }, forum_type: { list: '1,2,3,4', code: :missing_field } }, forum.error_options)
  end

  def test_numericality_params_invalid
    controller_params = { 'forum_category_id' => 'x' }
    item = nil
    forum = ApiDiscussions::ForumValidation.new(controller_params, item)
    refute forum.valid?(:update)
    assert forum.errors.full_messages.include?('Forum category datatype_mismatch')
    assert_equal({ name: { expected_data_type: String, code: :missing_field },
                   forum_category_id: { expected_data_type: :'Positive Integer', prepend_msg: :input_received, given_data_type: String },
                   forum_visibility: { list: '1,2,3,4', code: :missing_field },
                   forum_type: { list: '1,2,3,4', code: :missing_field } }, forum.error_options)
  end

  def test_inclusion_params_invalid
    controller_params = { 'forum_type' => '1', 'forum_visibility' => '1', 'company_ids' => 'test' }
    item = nil
    forum = ApiDiscussions::ForumValidation.new(controller_params, item)
    refute forum.valid?
    error = forum.errors.full_messages
    assert error.include?('Forum visibility not_included')
    assert error.include?('Forum type not_included')
    assert_equal({ name: {  expected_data_type: String, code: :missing_field }, forum_visibility: { list: '1,2,3,4', code: :datatype_mismatch, prepend_msg: :input_received, given_data_type: String },
                   forum_type: { list: '1,2,3,4', code: :datatype_mismatch, prepend_msg: :input_received, given_data_type: String } }, forum.error_options)
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
    assert_equal({ name: {  expected_data_type: String, code: :missing_field }, forum_visibility: { list: '1,2,3,4' },
                   forum_type: { list: '1,2,3,4' } }, forum.error_options)
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
    refute forum.errors.full_messages.include?('Forum category datatype_mismatch')
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
    controller_params = { forum_type: nil }.stringify_keys!
    item = Forum.new(forum_type: 1, forum_visibility: 1, topics_count: 2, forum_category_id: 1, name: Faker::Name.name)
    item.forum_category_id = 1
    forum = ApiDiscussions::ForumValidation.new(controller_params, item)
    refute forum.valid?(:update)
    assert_equal ['Forum type cannot_set_forum_type'], forum.errors.full_messages
    assert_equal({ name: {}, forum_category_id: {}, forum_visibility: {},
                   forum_type: { code: :incompatible_field } }, forum.error_options)
  end

  def test_company_ids_invalid
    controller_params = { company_ids: nil }.stringify_keys!
    item = Forum.new(forum_type: 1, forum_visibility: 1, topics_count: 2, forum_category_id: 1, name: Faker::Name.name)
    item.forum_category_id = 1
    forum = ApiDiscussions::ForumValidation.new(controller_params, item)
    refute forum.valid?(:update)
    assert_equal ['Company ids cannot_set_company_ids'], forum.errors.full_messages
    assert_equal({ name: {}, forum_category_id: {}, forum_visibility: {},
                   company_ids: { code: :incompatible_field } }, forum.error_options)

    controller_params = { company_ids: 'test' }.stringify_keys!
    item = Forum.new(forum_type: 1, forum_visibility: 1, topics_count: 2, forum_category_id: 1, name: Faker::Name.name)
    item.forum_category_id = 1
    forum = ApiDiscussions::ForumValidation.new(controller_params, item)
    refute forum.valid?(:update)
    assert_equal ['Company ids cannot_set_company_ids'], forum.errors.full_messages
    assert_equal({ name: {}, forum_category_id: {}, forum_visibility: {},
                   company_ids: { code: :incompatible_field } }, forum.error_options)

    controller_params = { company_ids: ['test'] }.stringify_keys!
    item = Forum.new(forum_type: 1, forum_visibility: 1, topics_count: 2, forum_category_id: 1, name: Faker::Name.name)
    item.forum_category_id = 1
    forum = ApiDiscussions::ForumValidation.new(controller_params, item)
    refute forum.valid?(:update)
    assert_equal ['Company ids cannot_set_company_ids'], forum.errors.full_messages
    assert_equal({ name: {}, forum_category_id: {}, forum_visibility: {},
                   company_ids: { code: :incompatible_field } }, forum.error_options)
  end

  def test_company_ids_datatype_mismatch
    controller_params = { company_ids: nil }
    item = Forum.new(forum_type: 1, forum_visibility: 4, topics_count: 2, forum_category_id: 1, name: Faker::Name.name)
    item.forum_category_id = 1
    forum = ApiDiscussions::ForumValidation.new(controller_params, item)
    refute forum.valid?(:update)
    assert_equal ['Company ids datatype_mismatch'], forum.errors.full_messages
    assert_equal({ name: {}, forum_visibility: {}, forum_category_id: {}, company_ids: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: 'Null'  } }, forum.error_options)
  end
end
