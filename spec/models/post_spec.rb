require 'spec_helper'

describe Post do
  before(:each) do
   # @topic = Factory(:topic)
   # @attrs = {:body => "Value for body",:user_id => 1}
  end

  
  
  describe "Topic Associations" do

    before(:each) do
      #@post =  @topic.posts.build(@attrs)
      @topic = Topic.find(1)
      @post =  Post.find(1)
    end

    it "should have a topic  attribute" do
      @post.should respond_to(:topic)
    end

    it "should have the right associated topic" do
       @post.topic_id.should == @topic.id
       @post.topic.should == @topic
    end
  end
  
end
