require_relative '../test_helper'

class CategoryValidationsTest < ActionView::TestCase
 
  test "should return the validated category object" do
    category = ApiDiscussions::CategoryValidation.new({"name" => "test", "description" => "test desc"})
    assert_equal category.name, "test"
    assert_equal category.description, "test desc"
    assert_equal category.valid?, true
  end

  test "should not be a valid category object if name is blank" do
    category = ApiDiscussions::CategoryValidation.new({})
    assert_equal category.valid?, false
    assert_equal category.errors.count, 1
    assert_equal category.errors.first.first, "name".to_sym
    assert_equal category.errors.first.last, "can't be blank"
  end
end