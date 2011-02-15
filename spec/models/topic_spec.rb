require 'spec_helper'

describe Topic do
  before(:each) do
    @forum = Factory(:forum)
    @attrs = {:title => "Freshdesk Topic"}
  end

  it "should create a new instance given valid attributes" do
     new_topic = @forum.topics.build(@attrs)
     new_topic.user = User.find(1);
     new_topic.should be_valid
 end
 it "should require a title" do
    no_topic_name =  @forum.topics.build(@attrs.merge(:title => ""))
    no_topic_name.user = User.find(1);
    no_topic_name.should_not be_valid
  end
  
  it "should require a user" do
    no_topic_user =  @forum.topics.build(@attrs)
    no_topic_user.should_not be_valid
  end
  
  describe "Forum Associations" do

    before(:each) do
      @topic = @forum.topics.build(@attrs)
      @topic.user = User.find(1);
    end

    it "should have a forum  attribute" do
      @topic.should respond_to(:forum)
    end

    it "should have the right associated forum" do
       @topic.forum_id.should == @forum.id
       @topic.forum.should == @forum
    end
  end
  
end
