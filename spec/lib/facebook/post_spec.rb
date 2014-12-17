require 'spec_helper'

RSpec.configure do |c|
  c.include FacebookHelper
  c.include Facebook::Core::Util
  c.include SocialHelper
end

RSpec.describe Facebook::Core::Post do
  
  before(:all) do
    @account.features.send(:facebook_realtime).create
    @account = create_test_account
    @account.make_current
    @fb_page = create_test_facebook_page(@account, false)
    Social::FacebookPage.update_all("import_visitor_posts = true", "page_id = #{@fb_page.page_id}")
    @account.features.send(:facebook_realtime).create
    if @account.features?(:social_revamp)
      @default_stream = @fb_page.default_stream
      @ticket_rule = create_test_ticket_rule(@default_stream, @account)
    end
  end

  it "should create a ticket when a post/status(without comments) arrives and import visitor post is enabled" do
    unless @account.features?(:social_revamp)
      feed_id = "#{@fb_page.page_id}_#{get_social_id}"
      realtime_feed = sample_realtime_feed(feed_id, "post")
      facebook_feed = sample_facebook_feed(true, feed_id)
      
      #stub the api call for koala
      Koala::Facebook::API.any_instance.stubs(:get_object).returns(facebook_feed)
      
      feed_id = facebook_feed[:id]
          
      Facebook::Core::Parser.new(realtime_feed).parse
      
      post = @account.facebook_posts.find_by_post_id(feed_id)
      post.should_not be_nil
      post.is_ticket?.should be true
      
      ticket = post.postable
      user_id = @account.users.find_by_fb_profile_id(facebook_feed[:from][:id]).id
      ticket.description.should eql facebook_feed[:message]
      ticket.subject.should eql truncate_subject(facebook_feed[:message], 100)
      ticket.requester_id.should eql user_id
    end
  end
  
  it "should create a ticket and notes to the ticket when a visitor post has comments and import visitor post is enabled" do    
    unless @account.features?(:social_revamp)
      feed_id = "#{@fb_page.page_id}_#{get_social_id}"
    
      realtime_feed = sample_realtime_feed(feed_id, "post")
      
      facebook_feed = sample_facebook_feed(true, feed_id, true)
      
      Koala::Facebook::API.any_instance.stubs(:get_object).returns(facebook_feed)
      
      Facebook::Core::Parser.new(realtime_feed).parse
      
      post = @account.facebook_posts.find_by_post_id(feed_id)
      post.should_not be_nil
      post.is_ticket?.should be true
      
      ticket = post.postable
      user_id = @account.users.find_by_fb_profile_id(facebook_feed[:from][:id]).id
      ticket.description.should eql facebook_feed[:message]
      ticket.requester_id.should eql user_id

      comment_feed = facebook_feed[:comments]["data"]
      post_comment = @account.facebook_posts.find_by_post_id(comment_feed.first[:id])
      post_comment.should_not be_nil
      post_comment.is_note?.should be true
      
      note = post_comment.postable
      note.notable.should eql ticket
      note.body.should eql comment_feed.first[:message]
    end
  end
 
  it "should not create a ticket when a post/status(without comments) arrives and import visitor post is not enabled" do  
    unless @account.features?(:social_revamp)
      Social::FacebookPage.update_all("import_visitor_posts = false", "page_id = #{@fb_page.page_id}") 
      feed_id = "#{@fb_page.page_id}_#{get_social_id}"
      realtime_feed = sample_realtime_feed(feed_id, "post")
      facebook_feed = sample_facebook_feed(true, feed_id)
      
      #stub the api call for koala
      Koala::Facebook::API.any_instance.stubs(:get_object).returns(facebook_feed)
      
      feed_id = facebook_feed[:id]
          
      Facebook::Core::Parser.new(realtime_feed).parse
      
      post = @account.facebook_posts.find_by_post_id(feed_id)
      post.should be_nil
    end
  end
 
  # it "should create a ticket when a post/status(without comments) arrives and matches a ticket rule" do
  #   feed_id = "#{@fb_page.page_id}_#{(Time.now.utc.to_f*100000).to_i}"
  #   realtime_feed = sample_realtime_feed(feed_id)
  #   facebook_feed = sample_facebook_feed(feed_id)
    
  #   #stub the api call for koala
  #   Koala::Facebook::API.any_instance.stubs(:get_object).returns(facebook_feed)
    
  #   feed_id = facebook_feed[:id]
  #   Facebook::Core::Parser.new(realtime_feed).parse
    
  #   post = Social::FbPost.find_by_post_id(feed_id)
  #   post.should_not be_nil
  #   post.is_ticket?.should be true
    
  #   ticket = post.postable
  #   user_id = @account.users.find_by_fb_profile_id(facebook_feed[:from][:id]).id
  #   ticket.description.should eql facebook_feed[:message]
  #   ticket.subject.should eql truncate_subject(facebook_feed[:message], 100)
  #   ticket.requester_id.should eql user_id
  # end
  
  # it "should not create a ticket when a post/status arrives and does not match a ticket rule" do
  #   feed_id = "#{(Time.now.utc.to_f*100000).to_i}_#{(Time.now.utc.to_f*100000).to_i}"
  #   realtime_feed = sample_realtime_feed(feed_id)
  #   facebook_feed = sample_facebook_feed(feed_id)
  #   facebook_feed[:message] = "Not me"
    
  #   #stub the api call for koala
  #   Koala::Facebook::API.any_instance.stubs(:get_object).returns(facebook_feed)
    
  #   Facebook::Core::Parser.new(realtime_feed).parse
    
  #   post = Social::FbPost.find_by_post_id(feed_id)
  #   post.should be_nil
  # end
  # it "should create a ticket and notes to the ticket when a post/status(with comments) arrives and matches a ticket rule" do
  #   feed_id = "#{@fb_page.page_id}_#{(Time.now.utc.to_f*100000).to_i}"
  #   realtime_feed = sample_realtime_feed(feed_id)
  #   facebook_feed = sample_facebook_feed(feed_id, true)
    
  #   #stub the api call for koala
  #   Koala::Facebook::API.any_instance.stubs(:get_object).returns(facebook_feed)
    
  #   Facebook::Core::Parser.new(realtime_feed).parse
    
  #   post = Social::FbPost.find_by_post_id(feed_id)
  #   post.should_not be_nil
  #   post.is_ticket?.should be true
    
  #   ticket = post.postable
  #   user_id = @account.users.find_by_fb_profile_id(facebook_feed[:from][:id]).id
  #   ticket.description.should eql facebook_feed[:message]
  #   ticket.subject.should eql truncate_subject(facebook_feed[:message], 100)
  #   ticket.requester.id.should eql user_id  
    
  #   comments =  facebook_feed[:comments].symbolize_keys
  #   comment = comments[:data].first
  #   user_id = @account.users.find_by_fb_profile_id(comment[:from][:id]).id
  #   post_comment = Social::FbPost.find_by_post_id(comment[:id])
  #   post_comment.should_not be_nil
  #   post_comment.is_note?.should be true
    
  #   note = post_comment.postable
  #   note.notable.should eql ticket
  #   note.body.should eql comment[:message]
  #   note.user.id.should eql user_id
  # end
  
  # it "should create a ticket and notes to the ticket when a post/status(with comments and reply to comments) arrives and matches a ticket rule" do
  #   feed_id = "#{@fb_page.page_id.to_i}_#{(Time.now.utc.to_f*100000).to_i}"
  #   realtime_feed = sample_realtime_feed(feed_id)
  #   facebook_feed = sample_facebook_feed(feed_id, true, true)
    
    
     
  #   #stub the api call for koala
  #   Koala::Facebook::API.any_instance.stubs(:get_object).returns(facebook_feed)
    
  #   Facebook::Core::Parser.new(realtime_feed).parse
    
  #   post = Social::FbPost.find_by_post_id(feed_id)
  #   post.should_not be_nil
  #   post.is_ticket?.should be true
    
  #   ticket = post.postable
  #   user_id = @account.users.find_by_fb_profile_id(facebook_feed[:from][:id]).id
  #   ticket.description.should eql facebook_feed[:message]
  #   ticket.subject.should eql truncate_subject(facebook_feed[:message], 100)
  #   ticket.requester.id.should eql user_id
    
  #   comments =  facebook_feed[:comments].symbolize_keys
  #   comment = comments[:data].first
  #   post_comment = Social::FbPost.find_by_post_id(comment[:id])
  #   post_comment.should_not be_nil
  #   post_comment.is_note?.should be true
    
  #   note = post_comment.postable
  #   user_id = @account.users.find_by_fb_profile_id(comment[:from][:id]).id
  #   note.notable.should eql ticket
  #   note.body.should eql comment[:message]
  #   note.user.id.should eql user_id
    
  #   reply_to_comments =  comment[:comments].symbolize_keys
  #   reply_to_comment = reply_to_comments[:data].first
  #   post_reply_to_comment = Social::FbPost.find_by_post_id(reply_to_comment[:id])
  #   post_reply_to_comment.should_not be_nil
  #   post_reply_to_comment.is_note?.should be true
    
  #   note = post_reply_to_comment.postable
  #   note.notable.should eql ticket
  #   user_id = @account.users.find_by_fb_profile_id(reply_to_comment[:from][:id]).id
  #   note.body.should eql reply_to_comment[:message]
  #   note.user.id.should eql user_id
  # end

end
