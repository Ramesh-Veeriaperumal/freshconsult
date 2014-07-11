require 'spec_helper'

include FacebookHelper

describe Social::FacebookPosts do
  
  before(:all) do
    @fb_page = create_test_facebook_page(@account)
  end
  
 
  it "should create a ticket when a company post(without comments) arrives and import company post is enabled" do   
    @fb_page.update_attributes(:import_company_posts => true)
    
    feed_id = "#{@fb_page.page_id}_#{get_id}"
    facebook_feed = sample_fql_feed(feed_id, true)
    Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:fql_query).returns(facebook_feed)
    Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_object).returns(sample_user_profile(@fb_page.page_id))  
    
    fb_posts = Social::FacebookPosts.new(@fb_page)
    fb_posts.fetch
    
    post = @account.facebook_posts.find_by_post_id(feed_id)
    post.should_not be_nil
    post.is_ticket?.should be_true
    
    ticket = post.postable
    user_id = @account.users.find_by_fb_profile_id(facebook_feed.first[:actor_id]).id
    ticket.description.should eql facebook_feed.first[:message]
    ticket.requester_id.should eql user_id
  end
  
  it "should create a ticket and notes to the ticket when a company post has comments and import company post is enabled" do
    @fb_page.update_attributes(:import_company_posts => true)
    feed_id = "#{@fb_page.page_id}_#{get_id}"
    facebook_feed = sample_fql_feed(feed_id, true, 1)
    Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:fql_query).returns(facebook_feed)
    Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_object).returns(sample_user_profile(@fb_page.page_id), sample_facebook_feed((feed_id)))  
    
    comment_feed = sample_fql_comment_feed(feed_id)
    Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_connections).returns(comment_feed)
    
    fb_posts = Social::FacebookPosts.new(@fb_page)
    fb_posts.fetch
    
    post = @account.facebook_posts.find_by_post_id(feed_id)
    post.should_not be_nil
    post.is_ticket?.should be_true
    
    ticket = post.postable
    user_id = @account.users.find_by_fb_profile_id(facebook_feed.first[:actor_id]).id
    ticket.description.should eql facebook_feed.first[:message]
    ticket.requester_id.should eql user_id

    
    post_comment = @account.facebook_posts.find_by_post_id(comment_feed.first[:id])
    post_comment.should_not be_nil
    post_comment.is_note?.should be_true
    
    note = post_comment.postable
    note.notable.should eql ticket
    note.body.should eql comment_feed.first[:message]
  end
  
  it "should create a ticket when a visitor post(without comments) arrives and import visitor post is enabled" do   
    @fb_page.update_attributes(:import_visitor_posts => true, :import_company_posts => false)
    
    feed_id = "#{@fb_page.page_id}_#{get_id}"
    facebook_feed = sample_fql_feed(feed_id, false)
    Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:fql_query).returns(facebook_feed)
    Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_object).returns(sample_user_profile(facebook_feed.first["actor_id"]))  
    
    fb_posts = Social::FacebookPosts.new(@fb_page)
    fb_posts.fetch
    
    post = @account.facebook_posts.find_by_post_id(feed_id)
    post.should_not be_nil
    post.is_ticket?.should be_true
    
    ticket = post.postable
    user_id = @account.users.find_by_fb_profile_id(facebook_feed.first[:actor_id]).id
    ticket.description.should eql facebook_feed.first[:message]
    ticket.requester_id.should eql user_id
  end
  
  it "should create a ticket and notes to the ticket when a visitor post has comments and import visitor post is enabled" do
    @fb_page.update_attributes(:import_visitor_posts => true, :import_company_posts => true)
    
    feed_id = "#{@fb_page.page_id}_#{get_id}"
    facebook_feed = sample_fql_feed(feed_id, false, 1)
    Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:fql_query).returns(facebook_feed)
    Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_object).returns(sample_user_profile(facebook_feed.first["actor_id"]))  
    
    comment_feed = sample_fql_comment_feed(feed_id)
    Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_connections).returns(comment_feed)
    
    
    fb_posts =  Social::FacebookPosts.new(@fb_page)
    fb_posts.fetch
    
    post = Social::FbPost.find_by_post_id(feed_id)
    post.should_not be_nil
    post.is_ticket?.should be_true
    
    ticket = post.postable
    user_id = @account.users.find_by_fb_profile_id(facebook_feed.first[:actor_id]).id
    ticket.description.should eql facebook_feed.first[:message]
    ticket.requester_id.should eql user_id
    
    post_comment = @account.facebook_posts.find_by_post_id(comment_feed.first[:id])
    post_comment.should_not be_nil
    post_comment.is_note?.should be_true
    
    note = post_comment.postable
    note.notable.should eql ticket
    note.body.should eql comment_feed.first[:message]
  end
  
  it "should create a ticket when a post(without comments) arrives and import visitor post or import company post is enabledis enabled" do   
    @fb_page.update_attributes(:import_visitor_posts => true, :import_company_posts => true)
    
    feed_id = "#{@fb_page.page_id}_#{get_id}"
    facebook_feed = sample_fql_feed(feed_id, false)
    Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:fql_query).returns(facebook_feed)
    Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_object).returns(sample_user_profile(facebook_feed.first["actor_id"]))  
    
    fb_posts = Social::FacebookPosts.new(@fb_page)
    fb_posts.fetch
    
    post = @account.facebook_posts.find_by_post_id(feed_id)
    post.should_not be_nil
    post.is_ticket?.should be_true
    
    ticket = post.postable
    user_id = @account.users.find_by_fb_profile_id(facebook_feed.first[:actor_id]).id
    ticket.description.should eql facebook_feed.first[:message]
    ticket.requester_id.should eql user_id
  end
  
  it "should process comments and add them as notes to the previously converted tickets" do
    @fb_page.update_attributes(:import_visitor_posts => true, :import_company_posts => true)
    feed_id = "#{@fb_page.page_id}_#{get_id}"
    facebook_feed = sample_fql_feed(feed_id, false)
    Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:fql_query).returns(facebook_feed)
    Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_object).returns(sample_user_profile(facebook_feed.first["actor_id"]))  
    
    comment_feed = sample_fql_comment_feed(feed_id)
    Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_connections).returns(comment_feed)
    
    
    fb_posts = Social::FacebookPosts.new(@fb_page)
    fb_posts.fetch
    
    post = @account.facebook_posts.find_by_post_id(feed_id)
    post.should_not be_nil
    post.is_ticket?.should be_true
    
    ticket = post.postable
    user_id = @account.users.find_by_fb_profile_id(facebook_feed.first[:actor_id]).id
    ticket.description.should eql facebook_feed.first[:message]
    ticket.requester_id.should eql user_id
    
    comment_id = "#{get_id}"
    sample_comment_feed = sample_fql_comment(feed_id, comment_id)
    Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:fql_query).returns(sample_comment_feed)
    fb_posts.get_comment_updates(get_id)
    post_comment = @account.facebook_posts.find_by_post_id(comment_id)
    post_comment.should_not be_nil
    post_comment.is_note?.should be_true
    
  end
  
  it "should not create a ticket when a post arrives and import visitor post is not enabled" do
    @fb_page.update_attributes(:import_visitor_posts => false, :import_company_posts => false)
    feed_id = "#{@fb_page.page_id}_#{get_id}"
    facebook_feed = sample_fql_feed(feed_id, false, 1)
    Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:fql_query).returns(facebook_feed)
    
    fb_posts = Social::FacebookPosts.new(@fb_page)
    fb_posts.fetch
    
    post = @account.facebook_posts.find_by_post_id(feed_id)
    post.should be_nil
   end
  
end
