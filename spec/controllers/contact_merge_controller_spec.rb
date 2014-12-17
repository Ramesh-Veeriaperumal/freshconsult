require 'spec_helper'
include FacebookHelper

describe ContactMergeController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @key_state = mue_key_state(@account)
    enable_mue_key(@account)
    @account.features.multiple_user_emails.create
    @account.features.contact_merge_ui.create
    @user1 = add_user_with_multiple_emails(@account, 2)
    @user2 = add_user_with_multiple_emails(@account, 2)
    Resque.inline = true
  end

  before(:each) do
    login_admin
  end

  after(:all) do
    Resque.inline = false
    @account.features.contact_merge_ui.destroy
    @account.features.multiple_user_emails.destroy
    disable_mue_key(@account) unless @key_state
  end

  it "should pass new contact merge" do
    post :new, :id => @user1.id
    response.body.should =~ /mergebox/
  end

  it "should pass contact merge confirm" do
    post :confirm, :parent_user => @user1.id, :ids => [@user2.id], :id => @user1.id
    response.body.should =~ /Please note that merging will move the entire set of emails, tickets, notes and contact information/
  end

  it "contact_merge complete" do
    post :complete, :parent_user => @user1.id, :target => [@user2.id]
    @account.user_emails.find_all_by_user_id(@user1.id).size.should eql 6
  end

  it "should merge contact with twitter" do
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
    twitter_dm = Twitter::DirectMessage.new(sample_dm)
    twitter_dm_array = [twitter_dm]
    Twitter::REST::Client.any_instance.stubs(:direct_messages).returns(twitter_dm_array)
    Social::Workers::Twitter::DirectMessage.perform({:account_id => @account.id})
    tweet = @account.tweets.find_by_tweet_id(sample_dm[:id])
    tweet.should_not be_nil
    tweet.is_ticket?.should be true
    ticket_body = tweet.tweetable.ticket_body.description
    ticket_body.should eql(sample_dm[:text])
    # tweet.tweetable.destroy
    ticket = tweet.tweetable
    user = tweet.tweetable.requester #this is the twitter contact
    user2 = add_user_with_multiple_emails(@account, 2)
    user2.reload
    #merging twitter contact with email contact
    post :complete, :parent_user => user2.id, :target => [user.id]
    ticket.reload
    ticket.requester_id.should eql user2.id
    @account.reload
    @account.users.find_by_twitter_id(sample_dm[:sender][:screen_name]).id.should eql user2.id
  end

  it "should merge with twitter primary contact" do
    #same as previous but merging email contact with twitter
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
    twitter_dm = Twitter::DirectMessage.new(sample_dm)
    twitter_dm_array = [twitter_dm]
    Twitter::REST::Client.any_instance.stubs(:direct_messages).returns(twitter_dm_array)
    Social::Workers::Twitter::DirectMessage.perform({:account_id => @account.id})
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
    post :complete, :parent_user => user.id, :target => [user2.id]
    ticket.reload
    ticket.requester_id.should eql user.id
    @account.reload
    @account.users.find_by_twitter_id(sample_dm[:sender][:screen_name]).id.should eql user.id
    @account.user_emails.user_for_email(email1).id.should eql user.id
    user.reload
    user.user_emails.length.should eql 3
  end

  it "should merge contact with facebook" do
    #create a facebook page, comment on it, convert comment to ticket and populate the user
    @fb_page = create_test_facebook_page(@account)
    @fb_page.update_attributes(:import_company_posts => true)
    feed_id = "#{@fb_page.page_id}_#{get_social_id}"
    facebook_feed = sample_fql_feed(feed_id, true)
    Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:fql_query).returns(facebook_feed)
    Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_object).returns(sample_user_profile(@fb_page.page_id))
    fb_posts = Facebook::Fql::Posts.new(@fb_page)
    fb_posts.fetch
    post1 = @account.facebook_posts.find_by_post_id(feed_id)
    post1.should_not be_nil
    post1.is_ticket?.should be true
    ticket = post1.postable
    user = @account.users.find_by_fb_profile_id(facebook_feed.first[:actor_id]) #this is the facebook user
    ticket.description.should eql facebook_feed.first[:message]
    ticket.requester_id.should eql user.id
    user2 = add_user_with_multiple_emails(@account, 2)
    user2.reload #email user
    #merging facebook user with email user
    post :complete, :parent_user => user2.id, :target => [user.id]
    @account.users.find_by_fb_profile_id(facebook_feed.first[:actor_id]).id.should eql user2.id
    ticket.reload
    ticket.requester_id.should eql user2.id
  end

  it "should merge with facebook primary contact" do
    #same as previous but merging email with facebook
    @fb_page = create_test_facebook_page(@account)
    @fb_page.update_attributes(:import_company_posts => true)
    feed_id = "#{@fb_page.page_id}_#{get_social_id}"
    facebook_feed = sample_fql_feed(feed_id, true)
    Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:fql_query).returns(facebook_feed)
    Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_object).returns(sample_user_profile(@fb_page.page_id))  
    fb_posts = Facebook::Fql::Posts.new(@fb_page)
    fb_posts.fetch
    post1 = @account.facebook_posts.find_by_post_id(feed_id)
    post1.should_not be_nil
    post1.is_ticket?.should be true
    ticket = post1.postable
    user = @account.users.find_by_fb_profile_id(facebook_feed.first[:actor_id])
    ticket.description.should eql facebook_feed.first[:message]
    ticket.requester_id.should eql user.id
    user2 = add_user_with_multiple_emails(@account, 2)
    email1 = user2.email
    user2.reload
    post :complete, :parent_user => user.id, :target => [user2.id]
    @account.users.find_by_fb_profile_id(facebook_feed.first[:actor_id]).id.should eql user.id
    ticket.reload
    ticket.requester_id.should eql user.id
    @account.user_emails.user_for_email(email1).id.should eql user.id
    user.reload
    user.user_emails.length.should eql 3
  end

  it "should merge contact with phone" do
    user1 = add_new_user(@account)
    user1.phone = "72364823489182931"
    user1.save
    user2 = add_user_with_multiple_emails(@account, 2)
    post :complete, :parent_user => user2.id, :target => [user1.id]
    @account.reload
    @account.users.find_by_phone("72364823489182931").id.should eql user2.id
  end

  it "should merge with phone primary" do
    user1 = add_new_user(@account)
    user1.phone = "72364823489188831"
    user1.save
    user2 = add_user_with_multiple_emails(@account, 2)
    email1 = user2.email
    post :complete, :parent_user => user1.id, :target => [user2.id]
    @account.reload
    @account.users.find_by_phone("72364823489188831").id.should eql user1.id
    @account.user_emails.user_for_email(email1).id.should eql user1.id
    user1.reload
    user1.user_emails.length.should eql 4
  end

  it "should merge contact from mobihelp" do
    #create new mobihelp user and merge it with email user
    user1 = create_mobihelp_user(@account, Faker::Internet.email, "11111-22222-3333333-3123123323")
    ticket_attributes = get_sample_mobihelp_ticket_attributes("Ticket_controller New test ticket123", "11111-22222-3333333-3123123323", user1)
    test_ticket = create_mobihelp_ticket(ticket_attributes)
    user2 = add_user_with_multiple_emails(@account, 2)
    post :complete, :parent_user => user2.id, :target => [user1.id]
    test_ticket.reload
    test_ticket.requester.id.should eql user2.id
  end

  it "should merge with mobihelp primary" do
    #same as previous but merging email with mobihelp
    user1 = create_mobihelp_user(@account, Faker::Internet.email, "11111-22222-3333333-3123123323")
    ticket_attributes = get_sample_mobihelp_ticket_attributes("Ticket_controller New test ticket123", "11111-22222-3333333-3123123323", user1)
    test_ticket = create_mobihelp_ticket(ticket_attributes)
    user2 = add_user_with_multiple_emails(@account, 2)
    email1 = user2.email
    post :complete, :parent_user => user1.id, :target => [user2.id]
    test_ticket.reload
    test_ticket.requester.id.should eql user1.id
    @account.user_emails.user_for_email(email1).id.should eql user1.id
    user1.reload
    user1.user_emails.length.should eql 4
  end

  it "should do a hybrid merge" do
    #merging twitter, facebook, phone, mobihelp, email users
    user1 = add_new_user(@account)
    user1.phone = "72364823484562931"
    user1.save
    user2 = add_user_with_multiple_emails(@account, 2)
    user3 = create_mobihelp_user(@account, Faker::Internet.email, "11111-22222-3333333-3123124323")
    ticket_attributes = get_sample_mobihelp_ticket_attributes("Ticket_controller New test ticket123", "11111-22222-3333333-3123124323", user3)
    test_ticket = create_mobihelp_ticket(ticket_attributes)
    @fb_page = create_test_facebook_page(@account)
    @fb_page.update_attributes(:import_company_posts => true)
    feed_id = "#{@fb_page.page_id}_#{get_social_id}"
    facebook_feed = sample_fql_feed(feed_id, true)
    Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:fql_query).returns(facebook_feed)
    Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_object).returns(sample_user_profile(@fb_page.page_id))  
    fb_posts = Facebook::Fql::Posts.new(@fb_page)
    fb_posts.fetch
    post1 = @account.facebook_posts.find_by_post_id(feed_id)
    post1.should_not be_nil
    post1.is_ticket?.should be true
    ticket = post1.postable
    user4 = @account.users.find_by_fb_profile_id(facebook_feed.first[:actor_id])
    ticket.description.should eql facebook_feed.first[:message]
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
    twitter_dm = Twitter::DirectMessage.new(sample_dm)
    twitter_dm_array = [twitter_dm]
    Twitter::REST::Client.any_instance.stubs(:direct_messages).returns(twitter_dm_array)
    Social::Workers::Twitter::DirectMessage.perform({:account_id => @account.id})
    tweet = @account.tweets.find_by_tweet_id(sample_dm[:id])
    tweet.should_not be_nil
    tweet.is_ticket?.should be true
    ticket_body = tweet.tweetable.ticket_body.description
    ticket_body.should eql(sample_dm[:text])
    # tweet.tweetable.destroy
    ticket2 = tweet.tweetable
    user5 = tweet.tweetable.requester
    post :complete, :parent_user => user2.id, :target => [user1.id, user3.id, user4.id, user5.id]
    test_ticket.reload
    ticket.reload
    ticket2.reload
    @account.reload
    test_ticket.requester.id.should eql user2.id
    ticket.requester.id.should eql user2.id
    ticket2.requester.id.should eql user2.id
    @account.users.find_by_phone("72364823484562931").id.should eql user2.id
    @account.users.find_by_fb_profile_id(facebook_feed.first[:actor_id]).id.should eql user2.id
    @account.users.find_by_twitter_id(sample_dm[:sender][:screen_name]).id.should eql user2.id
  end

  it "should search all except source contact" do
    request.env["HTTP_ACCEPT"] = "application/json"
    get :search, :id => @user1.id, :v => "a"
    response.body.should_not =~ /#{@user1.name}/
    response.body.should =~ /Rachel/
  end

  it "should not pass new contact merge for agent" do
    post :new, :id => @agent.id
    response.status.should eql 422
  end

end