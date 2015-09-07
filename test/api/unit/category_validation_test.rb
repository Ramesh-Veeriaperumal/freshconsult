require_relative '../unit_test_helper'

class CategoryValidationsTest < ActionView::TestCase
  def test_category_validation_params
    controller_params = { 'name' => 'test', 'description' => 'test desc' }
    item = ForumCategory.new
    category = ApiDiscussions::CategoryValidation.new(controller_params, item)
    assert_equal 'test', category.name
    assert_equal true, category.valid?
  end

  def test_category_validation_item
    item = ForumCategory.new(name: 'test')
    category = ApiDiscussions::CategoryValidation.new({}, item)
    assert_equal 'test', category.name
    assert_equal true, category.valid?
  end

  def test_category_validation_invalid
    item = ForumCategory.new
    category = ApiDiscussions::CategoryValidation.new({}, item)
    assert_equal false, category.valid?
    assert_equal 1, category.errors.count
    assert_equal 'name'.to_sym, category.errors.first.first
    assert_equal "can't be blank", category.errors.first.last
  end
end
