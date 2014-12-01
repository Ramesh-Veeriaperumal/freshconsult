require 'spec_helper'

include FacebookHelper
include SocialHelper
include Facebook::Core::Util

describe Facebook::Core::Post do
  
  before(:all) do
    @account.features.send(:facebook_realtime).create
    @account = create_test_account
    @account.make_current
    @fb_page = create_test_facebook_page(@account, true)
    Social::FacebookPage.update_all("import_visitor_posts = true", "page_id = #{@fb_page.page_id}")
    
    if @account.features?(:social_revamp)
      @default_stream = @fb_page.default_stream
      @ticket_rule = create_test_ticket_rule(@default_stream, @account)
    end
  end
  
  it "should create a note when a commmet arrives and the parent post is converted to a ticket" do
    unless @account.features?(:social_revamp)
      ticket, complete_post_id = sample_post_and_ticket
    
      post_id = complete_post_id.split("_").last
      comment_id = "#{post_id}_#{get_social_id}"
      realtime_feed = sample_realtime_comment_feed(comment_id)
      comment = sample_facebook_comment_feed(@fb_page.page_id, comment_id, "Comment to post")
      
      Koala::Facebook::API.any_instance.stubs(:get_object).returns(comment)
      
      Facebook::Core::Parser.new(realtime_feed).parse
      
      user_id = @account.users.find_by_fb_profile_id(comment[:from][:id]).id
      post_comment = Social::FbPost.find_by_post_id(comment[:id])
      post_comment.should_not be_nil
      post_comment.is_note?.should be_true
      
      note = post_comment.postable
      note.notable.should eql ticket
      note.body.should eql comment[:message]
      note.user.id.should eql user_id   
    end 
  end
  
  it "should create a ticket and note when the parent post is not converted to a ticket and import visitor posts in enabled and the comment is from a visitor" do
    unless @account.features?(:social_revamp)
      comment_id = "#{get_social_id}_#{get_social_id}"
      realtime_feed = sample_realtime_comment_feed(comment_id)
      comment = sample_facebook_comment_feed(@fb_page.page_id, comment_id, "Comment to post")
      
      feed_id = "#{@fb_page.page_id}_#{comment_id.split('_').first}"
      facebook_feed = sample_facebook_feed(true, feed_id, true)
      
      #stub the api call for koala
      Koala::Facebook::API.any_instance.stubs(:get_object).returns(comment, facebook_feed)
      
      Facebook::Core::Parser.new(realtime_feed).parse
      
      post = @account.facebook_posts.find_by_post_id(feed_id)
      post.should_not be_nil
      post.is_ticket?.should be_true
      
      ticket = post.postable
      user_id = @account.users.find_by_fb_profile_id(facebook_feed[:from][:id]).id
      ticket.description.should eql facebook_feed[:message]
      ticket.requester_id.should eql user_id

      comment_feed = facebook_feed[:comments]["data"]
      post_comment = @account.facebook_posts.find_by_post_id(comment_feed.first[:id])
      post_comment.should_not be_nil
      post_comment.is_note?.should be_true
      
      note = post_comment.postable
      note.notable.should eql ticket
      note.body.should eql comment_feed.first[:message]
    end  
  end
  
   it "should create a ticket and note when the parent post is not converted to a ticket and import company posts in enabled and the comment is from a company" do
    Social::FacebookPage.update_all("import_company_posts = true", "page_id = #{@fb_page.page_id}")
    
    unless @account.features?(:social_revamp)
      comment_id = "#{get_social_id}_#{get_social_id}"
      realtime_feed = sample_realtime_comment_feed(comment_id)
      comment = sample_facebook_comment_feed(@fb_page.page_id, comment_id, "Comment to post")
      
      feed_id = "#{@fb_page.page_id}_#{comment_id.split('_').first}"
      facebook_feed = sample_facebook_feed(false, feed_id, true)
      
      #stub the api call for koala
      Koala::Facebook::API.any_instance.stubs(:get_object).returns(comment, facebook_feed)
      
      Facebook::Core::Parser.new(realtime_feed).parse
      
      post = @account.facebook_posts.find_by_post_id(feed_id)
      post.should_not be_nil
      post.is_ticket?.should be_true
      
      ticket = post.postable
      user_id = @account.users.find_by_fb_profile_id(facebook_feed[:from][:id]).id
      ticket.description.should eql facebook_feed[:message]
      ticket.requester_id.should eql user_id

      comment_feed = facebook_feed[:comments]["data"]
      post_comment = @account.facebook_posts.find_by_post_id(comment_feed.first[:id])
      post_comment.should_not be_nil
      post_comment.is_note?.should be_true
      
      note = post_comment.postable
      note.notable.should eql ticket
      note.body.should eql comment_feed.first[:message]
    end  
  end
  
  # it "should create a note when a commmet arrives and the parent post is converted to a ticket and replies are disabled" do
  #   ticket, complete_post_id = sample_post_and_ticket
    
  #   post_id = complete_post_id.split("_").last
  #   comment_id = "#{post_id}_#{(Time.now.utc.to_f*100000).to_i}"
  #   realtime_feed = sample_realtime_comment_feed(comment_id)
  #   comment = sample_facebook_comment_feed(@fb_page.page_id, comment_id, "Comment to post")
    
  #   Koala::Facebook::API.any_instance.stubs(:get_object).returns(comment)
    
  #   Facebook::Core::Parser.new(realtime_feed).parse
    
  #   user_id = @account.users.find_by_fb_profile_id(comment[:from][:id]).id
  #   post_comment = Social::FbPost.find_by_post_id(comment[:id])
  #   post_comment.should_not be_nil
  #   post_comment.is_note?.should be_true
    
  #   note = post_comment.postable
  #   note.notable.should eql ticket
  #   note.body.should eql comment[:message]
  #   note.user.id.should eql user_id    
  # end
  
  # it "should create a ticket  and note when a commmet arrives, matches a ticket rule when the parent post is not converted to a ticket and replies are disabled" do
  #   #CHeck how to stub two API calls
  # end
  
  # it "should not create a ticket when a commmet arrives and does not match a ticket rule when the parent post is not converted to a ticket and replies are disabled" do
   
  #   comment_id = "#{(Time.now.utc.to_f*100000).to_i}_#{(Time.now.utc.to_f*100000).to_i}"
  #   realtime_feed = sample_realtime_comment_feed(comment_id)
  #   comment = sample_facebook_comment_feed(@fb_page.page_id, comment_id, "Comment to post")
    
  #   Koala::Facebook::API.any_instance.stubs(:get_object).returns(comment)
    
  #   Facebook::Core::Parser.new(realtime_feed).parse
    
  #   user_id = @account.users.find_by_fb_profile_id(comment[:from][:id]).id
  #   post_comment = Social::FbPost.find_by_post_id(comment[:id])
  #   post_comment.should be_nil
  # end
  
  # it "should create a note when a commmet arrives and the parent post is converted to a ticket and replies are enabled" do
  #   data = @default_stream.data.merge!({:replies_enabled => true})
  #   @default_stream.update_attributes(:data => data)
    
  #   ticket, complete_post_id = sample_post_and_ticket
    
  #   post_id = complete_post_id.split("_").last
  #   comment_id = "#{post_id}_#{(Time.now.utc.to_f*100000).to_i}"
  #   realtime_feed = sample_realtime_comment_feed(comment_id)
  #   comment = sample_facebook_comment_feed(@fb_page.page_id, comment_id, "Comment to post")
    
  #   Koala::Facebook::API.any_instance.stubs(:get_object).returns(comment)
    
  #   Facebook::Core::Parser.new(realtime_feed).parse
    
  #   user_id = @account.users.find_by_fb_profile_id(comment[:from][:id]).id
  #   post_comment = Social::FbPost.find_by_post_id(comment[:id])
  #   post_comment.should_not be_nil
  #   post_comment.is_note?.should be_true
    
  #   note = post_comment.postable
  #   note.notable.should eql ticket
  #   note.body.should eql comment[:message]
  #   note.user.id.should eql user_id    
  # end
  
  # it "should create a ticket when a commmet arrives, matches a ticket rule when the parent post is not converted to a ticket and replies are enabled" do
   
  #   data = @default_stream.data.merge!({:replies_enabled => true})
  #   @default_stream.update_attributes(:data => data)
  #   comment_id = "#{(Time.now.utc.to_f*100000).to_i}_#{(Time.now.utc.to_f*100000).to_i}"
  #   realtime_feed = sample_realtime_comment_feed(comment_id)
  #   comment = sample_facebook_comment_feed(@fb_page.page_id, comment_id, "Comment to post on facebook")
    
  #   Koala::Facebook::API.any_instance.stubs(:get_object).returns(comment)
    
  #   Facebook::Core::Parser.new(realtime_feed).parse
    
  #   user_id = @account.users.find_by_fb_profile_id(comment[:from][:id]).id
  #   post_comment = Social::FbPost.find_by_post_id(comment[:id])
  #   post_comment.should_not be_nil
  #   post_comment.is_ticket?.should be_true
    
  #   ticket = post_comment.postable
  #   ticket.description.should eql comment[:message]
  #   ticket.subject.should eql truncate_subject(comment[:message], 100)
  #   ticket.requester_id.should eql user_id
  # end
  
  # it "should not create a ticket when a commmet arrives and does not match a ticket rule when the parent post is not converted to a ticket and replies are enabled" do
    
  #   data = @default_stream.data.merge!({:replies_enabled => true})
  #   @default_stream.update_attributes(:data => data)
   
  #   comment_id = "#{(Time.now.utc.to_f*100000).to_i}_#{(Time.now.utc.to_f*100000).to_i}"
  #   realtime_feed = sample_realtime_comment_feed(comment_id)
  #   comment = sample_facebook_comment_feed(@fb_page.page_id, comment_id, "Comment to post")
    
  #   Koala::Facebook::API.any_instance.stubs(:get_object).returns(comment)
    
  #   Facebook::Core::Parser.new(realtime_feed).parse
    
  #   user_id = @account.users.find_by_fb_profile_id(comment[:from][:id]).id
  #   post_comment = Social::FbPost.find_by_post_id(comment[:id])
  #   post_comment.should be_nil
  # end
  
end
