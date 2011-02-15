require 'spec_helper'

describe ForumCategory do
  before(:each) do
    @valid_attributes = {
      :name => "value for name",
      :description => "value for description",
      :account_id => 1
    }
  end
  
  #positive test case
  it "should create a new instance given valid attributes" do
    ForumCategory.create!(@valid_attributes)
  end
  
  #negative test case
  it "should require a name" do
    no_forum_category_name = ForumCategory.new(@valid_attributes.merge(:account_id => ""))
    no_forum_category_name.should_not be_valid
  end
  
   #negative test case
  it "should require a account" do
    no_forum_category_account = ForumCategory.new(@valid_attributes.merge(:name => ""))
    no_forum_category_account.should_not be_valid
  end
  
  describe "forums associations" do

    before(:each) do
      @forum_category = ForumCategory.create(@valid_attributes)
    end

    it "should have a forum attribute" do
      @forum_category.should respond_to(:forums)
    end
  end
  
end
