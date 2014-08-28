require 'spec_helper'

include FacebookHelper

describe Facebook::Worker::FacebookMessage do
  self.use_transactional_fixtures = false
  
  before(:all) do
    @fb_page = create_test_facebook_page(@account)
  end

  it "should process posts and messages while called via resque" do 
    @fb_page.update_attributes({:import_company_posts => true, :realtime_subscription => false})
    
    feed_id = "#{@fb_page.page_id}_#{get_social_id}"
    facebook_feed = sample_fql_feed(feed_id, true)
    Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:fql_query).returns(facebook_feed, [])
    sample_feed = sample_facebook_feed(feed_id)
    sample_feed["type"] = "video"
    Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_object).returns(sample_user_profile(@fb_page.page_id))
    Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_object).returns(sample_feed)  
    
    thread_id = Time.now.utc.to_i
    actor_id = thread_id + 1
    msg_id = thread_id + 2
    
    sample_dm = sample_dm_threads(thread_id, actor_id, msg_id)
    Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_connections).returns(sample_dm)
    
    Facebook::Worker::FacebookMessage.perform({:account_id => @account.id})
    
    post = @account.facebook_posts.find_by_post_id(feed_id)
    post.should_not be_nil
    post.is_ticket?.should be true
    
    ticket = post.postable
    user_id = @account.users.find_by_fb_profile_id(facebook_feed.first[:actor_id]).id
    ticket.description.should eql facebook_feed.first[:message]
    ticket.requester_id.should eql user_id
    
    post = @account.facebook_posts.find_by_post_id(msg_id)
    post.should_not be_nil
    post.is_ticket?.should be true
  end
  
end
