require 'spec_helper'

RSpec.configure do |c|
  c.include FacebookHelper
  c.include Facebook::Core::Util
end

RSpec.describe Facebook::Core::Status do
  
  before(:all) do
    #@account = create_test_account
    @account.make_current
    @fb_page = create_test_facebook_page(@account, false)
    @account.features.send(:facebook_realtime).create
    Social::FacebookPage.update_all("import_company_posts = true", "page_id = #{@fb_page.page_id}")
    @fb_page.reload
    if @account.features?(:social_revamp)
      @default_stream = @fb_page.default_stream
      @ticket_rule = create_test_ticket_rule(@default_stream, @account)
    end
  end
  
  it "should create a ticket when a post/status(without comments) arrives and import company post is enabled" do   
    unless @account.features?(:social_revamp)
      feed_id = "#{@fb_page.page_id}_#{get_social_id}"
      realtime_feed = sample_realtime_feed(feed_id, "post")
      facebook_feed = sample_facebook_feed(false, feed_id)
      
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
  
  it "should create a ticket and notes to the ticket when a company post has comments and import company post is enabled" do    
    unless @account.features?(:social_revamp)
      feed_id = "#{@fb_page.page_id}_#{get_social_id}"
    
      realtime_feed = sample_realtime_feed(feed_id, "post")
      
      facebook_feed = sample_facebook_feed(false, feed_id, true)
      
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
      Social::FacebookPage.update_all("import_company_posts = false", "page_id = #{@fb_page.page_id}")  
      feed_id = "#{@fb_page.page_id}_#{get_social_id}"
      realtime_feed = sample_realtime_feed(feed_id, "post")
      facebook_feed = sample_facebook_feed(false, feed_id)
      
      #stub the api call for koala
      Koala::Facebook::API.any_instance.stubs(:get_object).returns(facebook_feed)
      
      feed_id = facebook_feed[:id]
          
      Facebook::Core::Parser.new(realtime_feed).parse
      
      post = @account.facebook_posts.find_by_post_id(feed_id)
      post.should be_nil
    end
  end
  
  # it "should create a ticket when a post(without comments) arrives and import company post is enabled" do
  #   feed_id = "#{@fb_page.page_id}_#{get_social_id}"
  #   realtime_feed = sample_realtime_feed(feed_id, "status")
  #   facebook_feed = sample_facebook_feed(feed_id, false, false, true)
  #   #stub the api call for koala
  #   Koala::Facebook::API.any_instance.stubs(:get_object).returns(facebook_feed)
    
  #   feed_id = facebook_feed[:id]
  #   Facebook::Core::Parser.new(realtime_feed).parse
  #   post = @account.facebook_posts.find_by_post_id(feed_id)
  #   post.should_not be_nil
  #   post.is_ticket?.should be true
    
  #   ticket = post.postable
  #   user_id = @account.users.find_by_fb_profile_id(facebook_feed[:from][:id]).id
  #   ticket.description.should eql facebook_feed[:message]
  #   ticket.subject.should eql truncate_subject(facebook_feed[:message], 100)
  #   ticket.requester_id.should eql user_id
  # end
  
  #  it "should create a ticket and notes to the ticket when a post(with comments) arrives and import company post is enabled" do
  #   feed_id = "#{@fb_page.page_id}_#{get_social_id}"
  #   realtime_feed = sample_realtime_feed(feed_id, "status")
  #   facebook_feed = sample_facebook_feed(feed_id, true, false, true)
    
  #   #stub the api call for koala
  #   Koala::Facebook::API.any_instance.stubs(:get_object).returns(facebook_feed)
    
  #   Facebook::Core::Parser.new(realtime_feed).parse
  #   post = @account.facebook_posts.find_by_post_id(feed_id)
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
  #   post_comment = @account.facebook_posts.find_by_post_id(comment[:id])
  #   post_comment.should_not be_nil
  #   post_comment.is_note?.should be true    
  #   note = post_comment.postable
  #   note.notable.should eql ticket
  #   note.body.should eql comment[:message]
  #   note.user.id.should eql user_id
  # end
  
  # it "raise an api limit exception for koala and check if it is reenqueued into sqs" do
  #   feed_id = "#{@fb_page.page_id}_#{get_social_id}"
  #   realtime_feed = sample_realtime_feed(feed_id, "status")
    
  #  error_info = {
  #     "code" => 4,
  #     "message" => "Error"
  #   }
  #   Koala::Facebook::API.any_instance.stubs(:get_object).raises(Koala::Facebook::APIError.new(400, "message is requeued", error_info))
    
  #   AwsWrapper::Sqs.any_instance.expects(:requeue).returns(true)
  #   Facebook::Core::Parser.new(realtime_feed).parse   
  # end
  
  
  it "authentication error check if it is pushed into dynamo db" do
    feed_id = "#{@fb_page.page_id}_#{get_social_id}"
    realtime_feed = sample_realtime_feed(feed_id, "status")
    
    error_info = {
      "code" => 190,
      "message" => "manage_pages"
    }
    
    Koala::Facebook::API.any_instance.stubs(:get_object).raises(Koala::Facebook::APIError.new(400, "message is pushed to dynamo db access token", error_info))
    
    AwsWrapper::DynamoDb.any_instance.expects(:write).returns(true)
    Facebook::Core::Parser.new(realtime_feed).parse
    @account.facebook_pages.find_by_page_id(@fb_page.page_id).reauth_required.should be true
    @account.facebook_pages.find_by_page_id(@fb_page.page_id).enable_page.should be false
  end
  
  # it "should not create a ticket when a post arrives and import company post is not enabled" do
  #    @fb_page.update_attributes(:import_company_posts => false)
  #    feed_id = "#{get_social_id}_#{get_social_id}"
  #    realtime_feed = sample_realtime_feed(feed_id, "status")
  #    facebook_feed = sample_facebook_feed(feed_id, false, false, true)
  #    facebook_feed[:message] = "Not me"
     
  #    #stub the api call for koala
  #    Koala::Facebook::API.any_instance.stubs(:get_object).returns(facebook_feed)
     
  #    Facebook::Core::Parser.new(realtime_feed).parse
     
  #    post = @account.facebook_posts.find_by_post_id(feed_id)
  #    post.should be_nil
  #  end
  
end
