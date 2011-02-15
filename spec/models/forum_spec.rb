require 'spec_helper'

describe Forum do
  before(:each) do
    @forum_category = Factory(:forum_category)
    @attrs = {:name => "Freshdesk forum"}
   
  end

  it "should create a new instance given valid attributes" do
    @forum_category.forums.create!(@attrs)
  end
  
  #negative test case
  it "should require a name" do
    no_forum_name = @forum_category.forums.build(@attrs.merge(:name => ""))
    no_forum_name.should_not be_valid
  end
  
  it "should be a ideas forum with forum type 2" do
      ideas_forum = @forum_category.forums.build(@attrs.merge(:forum_type => 2))
      ideas_forum.ideas?.should be_true
  end
  
  it "should not be a ideas forum for type 1" do
      no_ideas_forum = @forum_category.forums.build(@attrs.merge(:forum_type => 1))
      no_ideas_forum.ideas?.should_not be_true
  end
  
  it "should be a questions forum with forum type 3" do
      questions_forum = @forum_category.forums.build(@attrs.merge(:forum_type => 3))
      questions_forum.questions?.should be_true
  end
  
  it "should not be a questions forum for type 1" do
      no_questions_forum = @forum_category.forums.build(@attrs.merge(:forum_type => 1))
      no_questions_forum.questions?.should_not be_true
  end
  
  
  describe "Forum Category Associations" do

    before(:each) do
      @forum =  @forum_category.forums.create!(@attrs)
    end

    it "should have a forum category attribute" do
      @forum.should respond_to(:forum_category)
    end

    it "should have the right associated forum category" do
       @forum.forum_category_id.should == @forum_category.id
       @forum.forum_category.should == @forum_category
    end
  end
end
