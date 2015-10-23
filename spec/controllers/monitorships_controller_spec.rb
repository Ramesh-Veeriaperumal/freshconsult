require 'spec_helper'

describe MonitorshipsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    login_admin
  end

  describe "Forum" do

    before(:each) do
      @forum_category = create_test_category
      @forum = create_test_forum(@forum_category)
    end

    it "should follow forum" do
      old_followers_count = @forum.monitors.count
      post :toggle, :object => "forum" ,
           :id => @forum.id , 
           :type => "follow"
      @forum.reload
      @forum.monitors.count.should == old_followers_count+1
      @forum.monitors.last.id == User.current.id
    end

    it "should add other agent as follower" do
      @user = add_test_agent(@account)
      old_followers_count = @forum.monitors.count
      post :toggle, :object => "forum" ,
           :id => @forum.id , 
           :type => "follow",
           :user_id => @user.id
      @forum.reload
      @forum.monitors.count.should == old_followers_count+1
      @forum.monitors.last.id == @user.id
    end

    it "should unfollow forum" do

      old_followers_count = @forum.monitors.count
      post :toggle, :object => "forum" ,
           :id => @forum.id , 
           :type => "follow"
      @forum.reload
      @forum.monitors.count.should == old_followers_count+1
      @forum.monitors.last.id == User.current.id

      old_followers_count = @forum.monitors.count

      post :toggle, :object => "forum" ,
           :id => @forum.id , 
           :type => "unfollow"
      @forum.reload
      @forum.monitors.count.should == old_followers_count-1
    end

    it "should send notification mail on adding other agent as follower" do
      @user = add_test_agent(@account)
      old_followers_count = @forum.monitors.count
      post :toggle, :object => "forum" ,
           :id => @forum.id , 
           :type => "follow",
           :user_id => @user.id
      @forum.reload
      @forum.monitors.count.should == old_followers_count+1
      @forum.monitors.last.id == @user.id
      Delayed::Job.last.handler.should include('ForumMailer')
      Delayed::Job.last.handler.should include('notify_new_follower')
    end

  end


  describe "Topic" do

    before(:each) do
      @forum_category = create_test_category
      @forum = create_test_forum(@forum_category)
      @topic = create_test_topic(@forum)
    end

    it "should follow topic" do
      old_followers_count = @topic.monitors.count
      post :toggle, :object => "topic" ,
           :id => @topic.id , 
           :type => "follow"
      @topic.reload
      @topic.monitors.count.should == old_followers_count+1
      @topic.monitors.last.id == User.current.id
    end

    it "should add other agent as follower" do
      @user = add_test_agent(@account)
      old_followers_count = @topic.monitors.count
      post :toggle, :object => "topic" ,
           :id => @topic.id , 
           :type => "follow",
           :user_id => @user.id
      @topic.reload
      @topic.monitors.count.should == old_followers_count+1
      @topic.monitors.last.id == @user.id
    end

    it "should unfollow topic" do

      old_followers_count = @topic.monitors.count
      post :toggle, :object => "topic" ,
           :id => @topic.id , 
           :type => "follow"
      @topic.reload
      @topic.monitors.count.should == old_followers_count+1
      @topic.monitors.last.id == User.current.id

      old_followers_count = @topic.monitors.count
      post :toggle, :object => "topic" ,
           :id => @topic.id , 
           :type => "unfollow"
      @topic.reload

      @topic.monitors.count.should == old_followers_count-1
    end

    it "should send notification mail on adding other agent as follower" do
      @user = add_test_agent(@account)
      old_followers_count = @topic.monitors.count
      post :toggle, :object => "topic" ,
           :id => @topic.id , 
           :type => "follow",
           :user_id => @user.id
      @topic.reload
      @topic.monitorships.count.should == old_followers_count+1
      @topic.monitorships.last.user_id == @user.id
      Delayed::Job.last.handler.should include('TopicMailer')
      Delayed::Job.last.handler.should include('notify_new_follower')
    end
  end

  describe "Contact" do

    before(:each) do
      @user_contact = add_new_user(@account)
      @forum_category = create_test_category
      @forum = create_test_forum(@forum_category)
      @topic = create_test_topic(@forum)
    end

    it "should deactivate monitors (unfollow topics forums) when contact is deleted" do
      old_monitors_count = @user_contact.monitorships.active_monitors.count
      post :toggle, :object => "topic" ,
           :id => @topic.id , 
           :type => "follow",
           :user_id => @user_contact.id
      @topic.reload
      @user_contact.monitorships.active_monitors.count.should eql old_monitors_count+1
      Sidekiq::Testing.inline! do
        @user_contact.update_attribute(:deleted, true)
      end
      @user_contact.reload
      @user_contact.monitorships.active_monitors.count.should eql 0
    end

    it "should deactivate monitors (unfollow topics forums) when contact is blocked" do
      old_monitors_count = @user_contact.monitorships.active_monitors.count
      post :toggle, :object => "topic" ,
           :id => @topic.id , 
           :type => "follow",
           :user_id => @user_contact.id
      @topic.reload
      @user_contact.monitorships.active_monitors.count.should eql old_monitors_count+1
      Sidekiq::Testing.inline! do
        @user_contact.update_attribute(:blocked, true)
      end
      @user_contact.reload
      @user_contact.monitorships.active_monitors.count.should eql 0
    end
  
  end

end