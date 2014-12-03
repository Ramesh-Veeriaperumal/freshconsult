require 'spec_helper'

RSpec.configure do |c|
  c.include FacebookHelper
end

RSpec.describe Facebook::Core::Message do
  
  before(:all) do
    @fb_page = create_test_facebook_page(@account)
  end
  
  it "should convert a dm to a ticket when convert dm to ticket is enabled" do
    @fb_page.update_attributes(:import_dms => true)
    thread_id = Time.now.utc.to_i
    actor_id = thread_id + 1
    msg_id = thread_id + 2
    
    sample_dm = sample_dm_threads(thread_id, actor_id, msg_id)
    Koala::Facebook::API.any_instance.stubs(:get_connections).returns(sample_dm)
    
    fb_message = Facebook::Core::Message.new(@fb_page)
    fb_message.fetch_messages
    
    post = @account.facebook_posts.find_by_post_id(msg_id)
    post.should_not be_nil
    post.is_ticket?.should be_truthy
  end
  
  it "should convert a dm to a ticket and subsequent replies within the threded time to a note when dm to ticket is enabled" do
    @fb_page.update_attributes(:import_dms => true, :dm_thread_time => 86400)
    thread_id = Time.now.utc.to_i
    actor_id = thread_id + 1
    msg_id = thread_id + 2
    
    sample_dm = sample_dm_threads(thread_id, actor_id, msg_id)
    Koala::Facebook::API.any_instance.stubs(:get_connections).returns(sample_dm)
    
    fb_message = Facebook::Core::Message.new(@fb_page)
    fb_message.fetch_messages
    
    post = @account.facebook_posts.find_by_post_id(msg_id)
    post.should_not be_nil
    post.is_ticket?.should be_truthy
    
    actor_id = thread_id + 10
    msg_id = thread_id + 20
    sample_dm = sample_dm_threads(thread_id, actor_id, msg_id)
    Koala::Facebook::API.any_instance.stubs(:get_connections).returns(sample_dm)
    
    fb_message = Facebook::Core::Message.new(@fb_page)
    fb_message.fetch_messages
    
    post = @account.facebook_posts.find_by_post_id(msg_id)
    post.should_not be_nil
    post.is_note?.should be_truthy
  end
end
