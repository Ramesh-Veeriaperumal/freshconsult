require 'test/test_helper'

class Solution::FolderTest < ActiveSupport::TestCase

  # 1.Validate name
  # 2.Validate Duplicate name
  # 3. Validate presence of visibility
  # 4. Validate visibility 

  
     
  def setup
  	@folder = Solution::Folder.new
  end
  
  def test_with_invalid_name
  	assert !@folder.valid?, "Solution folder should not be valid without name"
    assert @folder.errors.invalid?(:name)
  end

  def test_with_invalid_visibility
    assert !@folder.valid?, "Solution folder should not be valid without visibility"
    assert @folder.errors.invalid?(:visibility)
  end

  def test_with_duplicate_name
    default_folder = Factory.create(:folder)
    @folder.name = default_folder.name
    assert !@folder.valid?, "Solution folder is having a duplicate name"
    assert ActiveRecord::Errors.default_error_messages[:taken],@folder.errors.on(:name)
  end

  def test_with_wrong_visibility
    @folder = Factory.build(:folder)
    @folder.visibility = 588888
    assert !@folder.valid?, "Solution folder is having a wrong visibility"
    assert @folder.errors.invalid?(:visibility)
  end


end