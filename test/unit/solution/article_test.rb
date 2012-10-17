require 'test/test_helper'

class Solution::ArticleTest < ActiveSupport::TestCase

  # 1.Validate name
  # 2.Validate Duplicate name
  # 3. Validate presence of visibility
  # 4. Validate visibility 

  
     
  def setup
  	@article = Solution::Article.new
  end
  
  def test_with_invalid_name
  	assert !@article.valid?, "Article should not be valid without name"
    assert @article.errors.invalid?(:title)
  end

  def test_with_invalid_with_out_account_id 
    @article = Factory.build(:article,:account_id => nil)
    assert !@article.valid?, "Article should not be valid without account"
    assert @article.errors.invalid?(:account_id)
  end

  def test_with_long_title
    @article = Factory.build(:article,:title => Forgery(:lorem_ipsum).words(100))
    assert !@article.valid?, "Article title must be proper"
    assert @article.errors.invalid?(:title)
  end

  def test_with_invalid_user
    @article = Factory.build(:article,:user_id => nil)
    assert !@article.valid?, "Article should not be valid without user"
    assert @article.errors.invalid?(:user_id)
  end


end