require 'test/test_helper'

class Solution::CategoryTest < ActiveSupport::TestCase

  # 1.Validate name
  # 2. Validate account
  # 3.validat Duplicate name

  
  # ActiveSupport::TestCase.fixture_path= File.dirname(__FILE__) +"/../../fixtures/**/"
  # fixtures :categories
  # set_fixture_class :categories => Solution::Category
   
  def setup
  	@category = Solution::Category.new
  end

  
  def test_with_invalid_name
  	assert !@category.valid?, "Solution category should not be valid without name"
    assert @category.errors.invalid?(:name)
  end

  def test_with_invalid_with_out_account_id 
    @category.name = "No Name"
    assert !@category.valid?, "Solution category should not be valid without account"
    assert @category.errors.invalid?(:account)
  end
  
  def test_with_duplicate_name
     solution_category = Factory.create(:solution_category)
     @category.name = solution_category.name
     assert !@category.valid?, "Solution category is having a duplictae name"
     assert ActiveRecord::Errors.default_error_messages[:taken],@category.errors.on(:name)
  end

end