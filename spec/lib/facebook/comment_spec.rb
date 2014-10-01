require 'spec_helper'

RSpec.configure do |c|
  c.include FacebookHelper
  c.include Facebook::Core::Util
end

RSpec.describe Facebook::Core::Comment do
  
  before(:all) do
    @account.features.send(:facebook_realtime).create
    @fb_page = create_test_facebook_page(@account)
    @fb_page.update_attributes(:import_visitor_posts => true, :import_company_posts => true)
  end
  
  it "should create a note when a commmet arrives and the parent post is converted to a ticket" do
    ticket, complete_post_id = sample_post_and_ticket
    
    post_id = complete_post_id.split("_").last
    comment_id = "#{post_id}_#{get_social_id}"
    realtime_feed = sample_realtime_comment_feed(comment_id)
    comment = sample_facebook_comment_feed(@fb_page.page_id, comment_id, "Comment to post")
    
    Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_object).returns(comment)
    
    Facebook::Core::Parser.new(realtime_feed).parse
    
    user_id = @account.users.find_by_fb_profile_id(comment[:from][:id]).id
    post_comment = @account.facebook_posts.find_by_post_id(comment[:id])
    post_comment.should_not be_nil
    post_comment.is_note?.should be true
    
    note = post_comment.postable
    note.notable.should eql ticket
    note.body.should eql comment[:message]
    note.user.id.should eql user_id    
  end
  
  it "create note and ticket when ticket is not present for the comment and convert to ticket is enabled" do
    feed_id = "#{@fb_page.page_id}_#{get_social_id}"
    post_id = feed_id.split("_").last
    comment_id = "#{post_id}_#{get_social_id}"
    
    realtime_feed = sample_realtime_comment_feed(comment_id)
    
    facebook_feed = sample_facebook_feed(feed_id, true)
    
    comment = sample_facebook_comment_feed(@fb_page.page_id, comment_id, "Comment to post")
     
    Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_object).returns(facebook_feed, comment)
    Facebook::Core::Parser.new(realtime_feed).parse
    
    post = @account.facebook_posts.find_by_post_id(feed_id)
    post.should_not be_nil
    post.is_ticket?.should be true
    ticket = post.postable
    
    ticket.notes.first.should_not be_nil
  end
  
end
