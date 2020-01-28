require 'spec_helper'
require 'sidekiq/testing'
include FacebookHelper

describe ContactMergeController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @key_state = mue_key_state(@account)
    enable_mue_key(@account)
    @account.reload
    @account.make_current
    custom_field_params.each do |field|
      params = cf_params(field)
      create_contact_field params 
    end
    @user1 = add_user_with_multiple_emails(@account, 1)
    @user2 = add_user_with_multiple_emails(@account, 1)
    @account.reload
  end

  before(:each) do
    login_admin
  end

  after(:all) do
    destroy_custom_fields
    disable_mue_key(@account) unless @key_state
  end

  it "should pass new contact merge" do
    post :new, :parent_user => @user1.id
    response.body.should =~ /mergebox/
  end

  it "should pass contact merge confirm" do
    request.env["HTTP_ACCEPT"] = "application/javascript"
    post :confirm, :parent_user => @user1.id, :target => [@user2.id], :id => @user1.id
    response.body.should =~ /Merging will move all the tickets, notes and contact information from the secondary contacts into #{@user1.name}. Also, the secondary contacts will been deleted and cannot be restored./
  end

  it "contact_merge merge" do
    post :merge, :parent_user => @user1.id, :target => [@user2.id]
    @account.user_emails.find_all_by_user_id(@user1.id).size.should eql 4
  end

  it "should merge contact with twitter" do
    Sidekiq::Testing.inline!
    #create a twitter handle, tweet, read tweet to ticket and find contact
    unless GNIP_ENABLED
      GnipRule::Client.any_instance.stubs(:list).returns([]) 
      GnipRule::Client.any_instance.stubs(:add).returns(add_response)
    end
    @handle = create_test_twitter_handle(@account)
    @handle.update_attributes(:capture_dm_as_ticket => true)
    @default_stream = @handle.default_stream
    @ticket_rule = create_test_ticket_rule(@default_stream)
    @data = @default_stream.data
    @rule = {:rule_value => @data[:rule_value], :rule_tag => @data[:rule_tag]}
    @account = @handle.account
    @account.make_current
    sample_dm = sample_twitter_dm("#{get_social_id}", Faker::Lorem.words(3), Time.zone.now.ago(3.days))
    # stub the api call
    Social::DynamoHelper.stubs(:insert).returns({})
    twitter_dm = Twitter::DirectMessage.new(sample_dm)
    twitter_dm_array = [twitter_dm]
    Twitter::REST::Client.any_instance.stubs(:direct_messages).returns(twitter_dm_array)
    Social::TwitterWorker.new.perform
    tweet = @account.tweets.find_by_tweet_id(sample_dm[:id])
    tweet.should_not be_nil
    tweet.is_ticket?.should be true
    ticket_body = tweet.tweetable.ticket_body.description
    ticket_body.should eql(sample_dm[:text])
    # tweet.tweetable.destroy
    ticket = tweet.tweetable
    user = tweet.tweetable.requester #this is the twitter contact
    twitter_id = user.twitter_id
    user2 = add_user_with_multiple_emails(@account, 2)
    user2.reload
    #merging twitter contact with email contact
    post :merge, :parent_user => user2.id, :target => [user.id]
    ticket.reload
    ticket.requester_id.should eql user2.id
    @account.reload
    @account.users.find_by_twitter_id(twitter_id).id.should eql user2.id
    Sidekiq::Testing.disable!
  end

  it "should merge with twitter primary contact" do
    #same as previous but merging email contact with twitter
    Sidekiq::Testing.inline!
    unless GNIP_ENABLED
      GnipRule::Client.any_instance.stubs(:list).returns([]) 
      GnipRule::Client.any_instance.stubs(:add).returns(add_response)
    end
    @handle = create_test_twitter_handle(@account)
    @handle.update_attributes(:capture_dm_as_ticket => true)
    @default_stream = @handle.default_stream
    @ticket_rule = create_test_ticket_rule(@default_stream)
    @data = @default_stream.data
    @rule = {:rule_value => @data[:rule_value], :rule_tag => @data[:rule_tag]}
    @account = @handle.account
    @account.make_current
    sample_dm = sample_twitter_dm("#{get_social_id}", Faker::Lorem.words(3), Time.zone.now.ago(3.days))
    # stub the api call
    Social::DynamoHelper.stubs(:insert).returns({})
    twitter_dm = Twitter::DirectMessage.new(sample_dm)
    twitter_dm_array = [twitter_dm]
    Twitter::REST::Client.any_instance.stubs(:direct_messages).returns(twitter_dm_array)
    Social::TwitterWorker.new.perform
    tweet = @account.tweets.find_by_tweet_id(sample_dm[:id])
    tweet.should_not be_nil
    tweet.is_ticket?.should be true
    ticket_body = tweet.tweetable.ticket_body.description
    ticket_body.should eql(sample_dm[:text])
    # tweet.tweetable.destroy
    ticket = tweet.tweetable
    user = tweet.tweetable.requester
    user2 = add_user_with_multiple_emails(@account, 2)
    email1 = user2.email
    user2.reload
    post :merge, :parent_user => user.id, :target => [user2.id]
    ticket.reload
    ticket.requester_id.should eql user.id
    @account.reload
    @account.users.find_by_twitter_id(sample_dm[:sender][:screen_name]).id.should eql user.id
    @account.user_emails.user_for_email(email1).id.should eql user.id
    user.reload
    user.user_emails.length.should eql 3
    Sidekiq::Testing.disable!
  end

  it "should merge contact with facebook" do
    #create a facebook page, comment on it, convert comment to ticket and populate the user
    Sidekiq::Testing.inline!
    @fb_page = create_test_facebook_page(@account)
    @fb_page.update_attributes(:import_visitor_posts => true)
    feed_id = "#{@fb_page.page_id}_#{get_social_id}"
    realtime_feed = sample_realtime_feed(feed_id, "post")
    facebook_feed = sample_facebook_feed(true, feed_id)
    #stub the api call for koala
    Koala::Facebook::API.any_instance.stubs(:get_object).returns(facebook_feed)
    feed_id = facebook_feed[:id]
    Facebook::Core::Parser.new(realtime_feed).parse
    @account.reload
    fpost = @account.facebook_posts.find_by_post_id(feed_id)
    fpost.should_not be_nil
    fpost.is_ticket?.should be true
    ticket = fpost.postable
    user = @account.users.find_by_fb_profile_id(facebook_feed[:from][:id])
    ticket.description.should eql facebook_feed[:message]
    ticket.requester_id.should eql user.id
    user2 = add_user_with_multiple_emails(@account, 2)
    user2.reload #email user
    #merging facebook user with email user

    post :merge, :parent_user => user2.id, :target => [user.id]
    @account.users.find_by_fb_profile_id(facebook_feed[:from][:id]).id.should eql user2.id
    ticket.reload
    ticket.requester_id.should eql user2.id
    Sidekiq::Testing.disable!
  end

  it "should merge with facebook primary contact" do
    #same as previous but merging email with facebook
    Sidekiq::Testing.inline!
    @fb_page = create_test_facebook_page(@account)
    @fb_page.update_attributes(:import_visitor_posts => true)
    feed_id = "#{@fb_page.page_id}_#{get_social_id}"
    realtime_feed = sample_realtime_feed(feed_id, "post")
    facebook_feed = sample_facebook_feed(true, feed_id)
    
    #stub the api call for koala
    Koala::Facebook::API.any_instance.stubs(:get_object).returns(facebook_feed)
    
    feed_id = facebook_feed[:id]
        
    Facebook::Core::Parser.new(realtime_feed).parse
    
    fpost = @account.facebook_posts.find_by_post_id(feed_id)
    fpost.should_not be_nil
    fpost.is_ticket?.should be true
    
    ticket = fpost.postable
    user = @account.users.find_by_fb_profile_id(facebook_feed[:from][:id])
    ticket.description.should eql facebook_feed[:message]
    ticket.requester_id.should eql user.id
    user2 = add_user_with_multiple_emails(@account, 2)
    email1 = user2.email
    user2.reload
    post :merge, :parent_user => user.id, :target => [user2.id]
    @account.users.find_by_fb_profile_id(facebook_feed[:from][:id]).id.should eql user.id
    ticket.reload
    ticket.requester_id.should eql user.id
    @account.user_emails.user_for_email(email1).id.should eql user.id
    user.reload
    user.user_emails.length.should eql 3
    Sidekiq::Testing.disable!
  end

  it "should merge contact with phone" do
    Sidekiq::Testing.inline!
    user1 = add_new_user(@account)
    user1.phone = "72364823489182931"
    user1.save
    user2 = add_user_with_multiple_emails(@account, 2)
    user2.phone = nil
    user2.save
    post :merge, :parent_user => user2.id, :target => [user1.id]
    @account.reload
    @account.users.find_by_phone("72364823489182931").id.should eql user2.id
    Sidekiq::Testing.disable!
  end

  it "should merge with phone primary" do
    Sidekiq::Testing.inline!
    user1 = add_new_user(@account)
    user1.phone = "72364823489188831"
    user1.save
    user2 = add_user_with_multiple_emails(@account, 2)
    email1 = user2.email
    post :merge, :parent_user => user1.id, :target => [user2.id]
    @account.reload
    @account.users.find_by_phone("72364823489188831").id.should eql user1.id
    @account.user_emails.user_for_email(email1).id.should eql user1.id
    user1.reload
    user1.user_emails.length.should eql 4
    Sidekiq::Testing.disable!
  end

  it "should do a hybrid merge" do
    Sidekiq::Testing.inline!
    #merging twitter, facebook, phone, email users
    user1 = add_new_user(@account)
    user1.phone = "72364823484562931"
    user1.save
    user2 = add_user_with_multiple_emails(@account, 2)
    user2.phone = nil
    user2.save
    @fb_page = create_test_facebook_page(@account)
    @fb_page.update_attributes(:import_visitor_posts => true)
    feed_id = "#{@fb_page.page_id}_#{get_social_id}"
    realtime_feed = sample_realtime_feed(feed_id, "post")
    facebook_feed = sample_facebook_feed(true, feed_id)
    
    #stub the api call for koala
    Koala::Facebook::API.any_instance.stubs(:get_object).returns(facebook_feed)
    
    feed_id = facebook_feed[:id]
        
    Facebook::Core::Parser.new(realtime_feed).parse
    
    fpost = @account.facebook_posts.find_by_post_id(feed_id)
    fpost.should_not be_nil
    fpost.is_ticket?.should be true
    
    ticket = fpost.postable
    user4 = @account.users.find_by_fb_profile_id(facebook_feed[:from][:id])
    ticket.description.should eql facebook_feed[:message]
    ticket.requester_id.should eql user4.id
    unless GNIP_ENABLED
      GnipRule::Client.any_instance.stubs(:list).returns([]) 
      GnipRule::Client.any_instance.stubs(:add).returns(add_response)
    end
    @handle = create_test_twitter_handle(@account)
    @handle.update_attributes(:capture_dm_as_ticket => true)
    @default_stream = @handle.default_stream
    @ticket_rule = create_test_ticket_rule(@default_stream)
    @data = @default_stream.data
    @rule = {:rule_value => @data[:rule_value], :rule_tag => @data[:rule_tag]}
    @account = @handle.account
    @account.make_current
    sample_dm = sample_twitter_dm("#{get_social_id}", Faker::Lorem.words(3), Time.zone.now.ago(3.days))
    # stub the api call
    Social::DynamoHelper.stubs(:insert).returns({})
    twitter_dm = Twitter::DirectMessage.new(sample_dm)
    twitter_dm_array = [twitter_dm]
    Twitter::REST::Client.any_instance.stubs(:direct_messages).returns(twitter_dm_array)
    Social::TwitterWorker.new.perform
    tweet = @account.tweets.find_by_tweet_id(sample_dm[:id])
    tweet.should_not be_nil
    tweet.is_ticket?.should be true
    ticket_body = tweet.tweetable.ticket_body.description
    ticket_body.should eql(sample_dm[:text])
    # tweet.tweetable.destroy
    ticket2 = tweet.tweetable
    user5 = tweet.tweetable.requester
    post :merge, :parent_user => user2.id, :target => [user1.id, user4.id, user5.id]
    ticket.reload
    ticket2.reload
    @account.reload
    ticket.requester.id.should eql user2.id
    ticket2.requester.id.should eql user2.id
    @account.users.find_by_phone("72364823484562931").id.should eql user2.id
    @account.users.find_by_fb_profile_id(facebook_feed[:from][:id]).id.should eql user2.id
    @account.users.find_by_twitter_id(sample_dm[:sender][:screen_name]).id.should eql user2.id
    Sidekiq::Testing.disable!
  end

  it "should search all except source contact" do
    request.env["HTTP_ACCEPT"] = "application/json"
    get :search, :parent_user => @user1.id, :v => "a"
    response.body.should_not =~ /#{@user1.name}/
    response.body.should =~ /Rachel/
  end

  it "should not pass new contact merge for agent" do
    post :new, :id => @agent.id
    response.status.should eql 422
  end

  it "should move all user attributes and custom fields from primary to secondary" do
    user1, user2 = add_new_user(@account), add_new_user(@account)
    user1.phone, user1.mobile = nil, nil
    user1.save
    default_attributes = contact_default_attribute_values
    default_attributes.each do |attr, value|
      user2.send("#{attr}=", value)
    end
    user2.custom_field = contact_fields_values_with_faker
    user2.save
    custom_field = user2.custom_field
    Sidekiq::Testing.inline!
    post :merge, :parent_user => user1.id, :target => [user2.id]
    Sidekiq::Testing.disable!
    user1.reload
    default_attributes.each do |attr, value|
      user1.send("#{attr}").should eql value
    end
    user1.custom_field.should eql custom_field
  end

end
