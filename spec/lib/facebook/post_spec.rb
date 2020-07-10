require 'spec_helper'

RSpec.configure do |c|
  c.include FacebookHelper
  c.include Social::Constants
end

RSpec.describe Facebook::Core::Post do
  
  self.use_transactional_fixtures = false
  
  before(:all) do
    @account.make_current
    @account.features.send(:social_revamp).create
    User.reset_current_user
    @fb_page        = create_test_facebook_page(@account)
    @default_stream = @fb_page.default_stream
  end
  
  describe "import_visitor_posts is enabled" do
    
    it "should create a ticket and push data to dynamo when a post(without comments) arrives" do
      @fb_page.update_attributes({:import_visitor_posts => true})
      
      feed_id   = "#{@fb_page.page_id}_#{get_social_id}"
      sender_id = "#{get_social_id}"
      
      #stub the api call for koala
      facebook_feed = sample_facebook_feed(sender_id, feed_id)
      Koala::Facebook::API.any_instance.stubs(:get_object).returns(facebook_feed)
      
      realtime_feed = sample_realtime_feed(feed_id, "post")
      Sqs::Message.new(realtime_feed).process
      
      facebook_feed.deep_symbolize_keys!
      
      #Check if post exists
      post = @account.facebook_posts.find_by_post_id(feed_id)
      post.should_not be_nil
      post.is_ticket?.should be true
      
      #Check ticket properties
      ticket  = post.postable
      user_id = @account.users.find_by_fb_profile_id(facebook_feed[:from][:id]).id
      ticket.description.should eql facebook_feed[:message]
      ticket.requester_id.should eql user_id    
      
      #Check feeds table for entries
      attributes_to_get = ["parent_feed_id", "in_conversation", "source", "fd_link", "fd_user", "comments_count"]
      dynamo_item = get_dynamo_feed("feeds", feed_id, attributes_to_get)
      
      if dynamo_item.item.present?
        feed = dynamo_item[:item]
        feed["comments_count"].should be nil
        feed["fd_link"][:ss].should  eql(["#{ticket.display_id}"])
        feed["fd_user"][:ss].should  eql(["#{ticket.requester_id}"])
        feed["parent_feed_id"][:ss].should eql(["#{feed_id}"])
      end
      
      #Check interaction table for entries
      attributes_to_get = ["feed_ids"]
      dynamo_item       = get_dynamo_feed("interactions", "feed:#{feed_id}", attributes_to_get)
      
      if dynamo_item
        feed = dynamo_item[:item]
        feed["feed_ids"][:ss].should eql(["#{feed_id}"])
      end
      
    end
    
    
    it "should create a ticket and push data to dynamo add the comments as notes when a post with comments arrive" do
      @fb_page.update_attributes({:import_visitor_posts => true})
      
      feed_id    = "#{@fb_page.page_id}_#{get_social_id}"
      comment_id = "#{feed_id.split('_').last}_#{get_social_id}"
      sender_id  = "#{get_social_id}"
      
      #stub the api call for koala
      facebook_feed = sample_facebook_feed(sender_id, feed_id, comment_id)
      Koala::Facebook::API.any_instance.stubs(:get_object).returns(facebook_feed)
      
      realtime_feed = sample_realtime_feed(feed_id, "post")
      Sqs::Message.new(realtime_feed).process
      
      facebook_feed.deep_symbolize_keys!
      
      #Check if post exists
      post = @account.facebook_posts.find_by_post_id(feed_id)
      post.should_not be_nil
      post.is_ticket?.should be true
      
      #Check ticket properties
      ticket  = post.postable
      user_id = @account.users.find_by_fb_profile_id(facebook_feed[:from][:id]).id
      ticket.description.should eql facebook_feed[:message]
      ticket.requester_id.should eql user_id 
      ticket.notes.count.should eql 1
      
      #Check if comment exists
      comment_post = @account.facebook_posts.find_by_post_id(comment_id) 
      comment_post.should_not be_nil
      comment_post.is_note?.should be true
      
      #Check note properties
      comment_feed = facebook_feed[:comments][:data].first
      note         = comment_post.postable
      comm_user_id = @account.users.find_by_fb_profile_id(comment_feed[:from][:id]).id
      note.body.should eql comment_feed[:message]
      note.user.id.should eql comm_user_id 
      note.notable.should eql ticket
      
      #Check feeds table for entries for post
      attributes_to_get = ["parent_feed_id", "in_conversation", "source", "fd_link", "fd_user", "comments_count"]
      dynamo_item = get_dynamo_feed("feeds", feed_id, attributes_to_get)
      
      
      if dynamo_item
        feed = dynamo_item[:item]
        feed["comments_count"][:n].should eql("1")
        feed["fd_link"][:ss].should  eql(["#{ticket.display_id}"])
        feed["fd_user"][:ss].should  eql(["#{ticket.requester_id}"])
        feed["parent_feed_id"][:ss].should eql(["#{feed_id}"])
      end
      
      #Check interaction table for entries for post
      attributes_to_get = ["feed_ids"]
      dynamo_item       = get_dynamo_feed("interactions", "feed:#{feed_id}", attributes_to_get)
      
      if dynamo_item
        feed = dynamo_item[:item]
        feed["feed_ids"][:ss].should eql(["#{comment_id}", "#{feed_id}"])
      end
      
      #Check feeds table for entries for comment
      attributes_to_get = ["parent_feed_id", "in_conversation", "source", "fd_link", "fd_user", "comments_count"]
      dynamo_item = get_dynamo_feed("feeds", comment_id, attributes_to_get)
      
      if dynamo_item
        feed = dynamo_item[:item]
        feed["comments_count"].should be nil
        feed["fd_link"][:ss].should  eql(["#{ticket.display_id}#note#{note.id}"])
        feed["fd_user"][:ss].should  eql(["#{note.user.id}"])
        feed["parent_feed_id"][:ss].should eql(["#{feed_id}"])
      end
      
      #Check interaction table for entries for comment
      attributes_to_get = ["feed_ids"]
      dynamo_item       = get_dynamo_feed("interactions", "feed:#{comment_id}", attributes_to_get)
      
      if dynamo_item
        feed = dynamo_item[:item]
        feed["feed_ids"][:ss].should eql(["#{comment_id}"])
      end
      
    end
    
  end
  
  describe "import_visitor_posts is not enabled" do
    
    it "should push data to dynamo and not create tickets when a post(without comments) arrives" do
      @fb_page.update_attributes({:import_visitor_posts => false})
      
      feed_id   = "#{@fb_page.page_id}_#{get_social_id}"
      sender_id = "#{get_social_id}"
      
      #stub the api call for koala
      facebook_feed = sample_facebook_feed(sender_id, feed_id)
      Koala::Facebook::API.any_instance.stubs(:get_object).returns(facebook_feed)
      
      realtime_feed = sample_realtime_feed(feed_id, "post")
      Sqs::Message.new(realtime_feed).process
      
      facebook_feed.deep_symbolize_keys!
      
      #Check if post exists
      post = @account.facebook_posts.find_by_post_id(feed_id)
      post.should be_nil
      
      
      #Check feeds table for entries
      attributes_to_get = ["parent_feed_id", "in_conversation", "source", "fd_link", "fd_user", "comments_count"]
      dynamo_item = get_dynamo_feed("feeds", feed_id, attributes_to_get)
      
      if dynamo_item
        feed = dynamo_item[:item]
        feed["comments_count"].should be nil
        feed["fd_link"].should be nil
        feed["fd_user"].should be nil
        feed["parent_feed_id"][:ss].should eql(["#{feed_id}"])
      end
      
      #Check interaction table for entries
      attributes_to_get = ["feed_ids"]
      dynamo_item       = get_dynamo_feed("interactions", "feed:#{feed_id}", attributes_to_get)
      
      if dynamo_item
        feed = dynamo_item[:item]
        feed["feed_ids"][:ss].should eql(["#{feed_id}"])
      end
      
    end
    
    
    it "should push post and comment data to dynamo and not create tickets when a post with comments arrive" do
      @fb_page.update_attributes({:import_visitor_posts => false})
      
      feed_id    = "#{@fb_page.page_id}_#{get_social_id}"
      comment_id = "#{feed_id.split('_').last}_#{get_social_id}"
      sender_id  = "#{get_social_id}"
      
      #stub the api call for koala
      facebook_feed = sample_facebook_feed(sender_id, feed_id, comment_id)
      Koala::Facebook::API.any_instance.stubs(:get_object).returns(facebook_feed)
      
      realtime_feed = sample_realtime_feed(feed_id, "post")
      Sqs::Message.new(realtime_feed).process
      
      facebook_feed.deep_symbolize_keys!
      
      #Check if post exists
      post = @account.facebook_posts.find_by_post_id(feed_id)
      post.should be_nil
      
      #Check if comment exists
      comment_post = @account.facebook_posts.find_by_post_id(comment_id) 
      comment_post.should
      
      #Check feeds table for entries for post
      attributes_to_get = ["parent_feed_id", "in_conversation", "source", "fd_link", "fd_user", "comments_count"]
      dynamo_item = get_dynamo_feed("feeds", feed_id, attributes_to_get)
      
      if dynamo_item
        feed = dynamo_item[:item]
        feed["comments_count"][:n].should eql("1")
        feed["fd_link"].should be nil
        feed["fd_user"].should be nil
        feed["parent_feed_id"][:ss].should eql(["#{feed_id}"])
      end
      
      #Check interaction table for entries for post
      attributes_to_get = ["feed_ids"]
      dynamo_item       = get_dynamo_feed("interactions", "feed:#{feed_id}", attributes_to_get)
      
      if dynamo_item
        feed = dynamo_item[:item]
        feed["feed_ids"][:ss].should eql(["#{comment_id}", "#{feed_id}"])
      end
      
      #Check feeds table for entries for comment
      attributes_to_get = ["parent_feed_id", "in_conversation", "source", "fd_link", "fd_user", "comments_count"]
      dynamo_item = get_dynamo_feed("feeds", comment_id, attributes_to_get)
      
      if dynamo_item
        feed = dynamo_item[:item]
        feed["comments_count"].should be nil
        feed["fd_link"].should be nil
        feed["fd_user"].should be nil
        feed["parent_feed_id"][:ss].should eql(["#{feed_id}"])
      end
      
      #Check interaction table for entries for comment
      attributes_to_get = ["feed_ids"]
      dynamo_item       = get_dynamo_feed("interactions", "feed:#{comment_id}", attributes_to_get)
      
      if dynamo_item
        feed = dynamo_item[:item]
        feed["feed_ids"][:ss].should eql(["#{comment_id}"])
      end
      
    end
    
  end

end
