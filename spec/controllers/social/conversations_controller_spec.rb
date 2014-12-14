   
require 'spec_helper'

RSpec.configure do |c|
  c.include GnipHelper
  c.include DynamoHelper
  c.include FacebookHelper
end

RSpec.describe Helpdesk::ConversationsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false
      
  describe "POST #twitter" do
    before(:all) do
      Resque.inline = true
      unless GNIP_ENABLED
        GnipRule::Client.any_instance.stubs(:list).returns([]) 
        Gnip::RuleClient.any_instance.stubs(:add).returns(add_response)
      end
      @handle = create_test_twitter_handle(@account)
      @handle.update_attributes(:capture_dm_as_ticket => true)
      @default_stream = @handle.default_stream
      @ticket_rule = create_test_ticket_rule(@default_stream)
      update_db(@default_stream) unless GNIP_ENABLED
      @rule = {:rule_value => @default_stream.data[:rule_value] , :rule_tag => @default_stream.data[:rule_tag]}
      Resque.inline = false
      @account = @handle.account
    end
    
    before(:each) do
      @account.make_current
      unless GNIP_ENABLED
        Social::DynamoHelper.stubs(:insert).returns({})
        Social::DynamoHelper.stubs(:update).returns({})
      end
      log_in(@agent)
    end
    
    context "For Tweets" do
      it "must reply to a tweet ticket" do
        # create a tweet ticket
        includes = @default_stream.includes
        @ticket_rule.filter_data[:includes] = includes
        @ticket_rule.save
        feed = sample_gnip_feed(@rule)
        tweet = send_tweet_and_wait(feed)
        
        tweet.should_not be_nil
        tweet.is_ticket?.should be true
        tweet.stream_id.should_not be_nil
        tweet_body = feed["body"]
        ticket = tweet.get_ticket
        body = ticket.ticket_body.description
        tweet_body.should eql(body)

        
        # stub the reply call
        twitter_object = sample_twitter_object
        Twitter::REST::Client.any_instance.stubs(:update).returns(twitter_object)
        unless GNIP_ENABLED
          Social::DynamoHelper.stubs(:update).returns(dynamo_update_attributes(twitter_object[:id]))
          Social::DynamoHelper.stubs(:get_item).returns(sample_dynamo_get_item_params)
        end
        request.env["HTTP_ACCEPT"] = "application/javascript"
        post :twitter,  { :helpdesk_note => {
                            :private => false, 
                            :source => 5, 
                            :note_body_attributes => {:body => twitter_object[:text].dup }
                         },
                        :tweet => true,
                        :tweet_type => "mention",
                        :twitter_handle => @handle.id,
                        :ticket_id => ticket.display_id ,
                        :ticket_status => "",
                        :format => "js"
                      }
        tweet_note = @account.tweets.find_by_tweet_id(twitter_object[:id])
        tweet_note.should_not be_nil
        tweet_note.is_note?.should be true
        note_body = tweet_note.tweetable.note_body.body
        note_body.should eql(twitter_object[:text])
      end
    end
    
    context "For private DM's" do
      it "must send a reply to a DM ticket" do
        # create a DM ticket
        sample_dm = sample_twitter_dm("#{get_social_id}", Faker::Lorem.words(3), Time.zone.now.ago(3.days))
        twitter_dm = Twitter::DirectMessage.new(sample_dm)
        twitter_dm_array = [twitter_dm]
        Twitter::REST::Client.any_instance.stubs(:direct_messages).returns(twitter_dm_array)
        Social::Workers::Twitter::DirectMessage.perform({:account_id => @account.id})
        tweet = @account.tweets.find_by_tweet_id(sample_dm[:id])
        tweet.should_not be_nil
        tweet.is_ticket?.should be true
        
        # replying to a DM ticket
        ticket = tweet.get_ticket
        dm_text = Faker::Lorem.sentence(3)
        reply_id = get_social_id
        dm_reply_params = {
          :id => reply_id,
          :id_str => "#{reply_id}",
          :recipient_id_str => rand.to_s[2..11],
          :text => dm_text ,
          :created_at => "#{Time.zone.now}"
        }
        sample_dm_reply = Twitter::DirectMessage.new(dm_reply_params)
        Twitter::REST::Client.any_instance.stubs(:create_direct_message).returns(sample_dm_reply)
        post :twitter, { :helpdesk_note => {
                            :private => false, 
                            :source => 5, 
                            :note_body_attributes => {:body => dm_text }
                         },
                        :tweet => true,
                        :tweet_type => "dm",
                        :twitter_handle => @handle.id,
                        :ticket_id => ticket.display_id ,
                        :ticket_status => "",
                        :format => "js"
                      }        
        dm = @account.tweets.find_by_tweet_id(reply_id)
        dm.should_not be_nil
        dm.is_note?.should be true
        note_body = dm.tweetable.note_body.body
        note_body.should eql(dm_text)
      end
    end
    
    after(:all) do
      Resque.inline = true
      unless GNIP_ENABLED
       GnipRule::Client.any_instance.stubs(:list).returns([]) 
       GnipRule::Client.any_instance.stubs(:delete).returns(delete_response)
      end
      @handle.destroy
      Resque.inline = false
    end
  end
  
  describe "POST #facebook" do
    before(:all) do
      @fb_page = FactoryGirl.build(:facebook_pages)
      @fb_page.realtime_subscription = false
      @fb_page.account_id = @account.id
      @fb_page.import_visitor_posts = true
      @fb_page.import_dms = true
      @fb_page.save(:validate => false)
    end
    
    before(:each) do
      @account.make_current
      log_in(@agent)
    end
    
    context "For FB posts" do
      it "must reply to a FB post(ticket)" do
        post_id = "#{(Time.now.ago(9.minutes).utc.to_f*100000).to_i}_#{(Time.now.ago(8.minutes).utc.to_f*100000).to_i}"
        put_comment_id = "#{(Time.now.ago(2.minutes).utc.to_f*100000).to_i}_#{(Time.now.ago(6.minutes).utc.to_f*100000).to_i}"
        fql_feeds = sample_fql_feed(post_id, true)
        facebook_feed = sample_facebook_feed(true, post_id).symbolize_keys!
        sample_put_comment = { "id" => put_comment_id }

        # stub the calls
        Facebook::Fql::Posts.any_instance.stubs(:get_html_content).returns(fql_feeds.first["message"])
        Koala::Facebook::API.any_instance.stubs(:fql_query).returns(fql_feeds)
        Koala::Facebook::API.any_instance.stubs(:get_object).returns(facebook_feed) 
        Koala::Facebook::API.any_instance.stubs(:put_comment).returns(sample_put_comment) 
        
        # Create FB post ticket
        Facebook::Fql::Posts.new(@fb_page).fetch
        fb_post = Social::FbPost.find_by_post_id(post_id)
        fb_post.should_not be_nil
        fb_post.is_ticket?.should be true
        ticket = fb_post.postable
         
        post :facebook, {   :helpdesk_note => 
                              { :source => 7, 
                                :private => false, 
                                :note_body_attributes => {:body => Faker::Lorem.sentence(3) }
                              },
                            :fb_post => true,
                            :format => "js",
                            :ticket_status => "",
                            :showing => "notes",
                            :ticket_id => ticket.display_id
                        }
        comment = Social::FbPost.find_by_post_id(put_comment_id)
        comment.should_not be_nil
        comment.is_note?.should be true
      end
    end
    
    context "For FB Private Msgs" do
      it "must reply to a FB private msg ticket" do
        actor_id = Time.now.ago(10.minutes).utc.to_i
        thread_id = generate_thread_id
        msg_id = generate_msg_id
        sample_fb_dms = sample_dm_threads(thread_id, actor_id, msg_id)
        Koala::Facebook::API.any_instance.stubs(:get_object).returns(sample_user_profile(actor_id))
        Koala::Facebook::API.any_instance.stubs(:get_connections).returns(sample_fb_dms)
        Facebook::Core::Message.new(@fb_page).fetch_messages
        
        dm = Social::FbPost.find_by_post_id(msg_id)
        dm.should_not be_nil
        dm.is_ticket?.should be true
        dm_ticket =  dm.postable
        
        reply_dm_id = generate_msg_id
        sample_reply_dm = { "id" => reply_dm_id }
        Koala::Facebook::API.any_instance.stubs(:put_object).returns(sample_reply_dm)
        post :facebook, {   :helpdesk_note => 
                              { :source => 7, 
                                :private => false, 
                                :note_body_attributes => {:body => Faker::Lorem.sentence(3) }
                              },
                            :fb_post => true,
                            :format => "js",
                            :ticket_status => "",
                            :showing => "notes",
                            :ticket_id => dm_ticket.display_id,
                        }
        dm_reply = Social::FbPost.find_by_post_id(reply_dm_id)
        dm_reply.should_not be_nil
        dm_reply.is_note?.should be true
      end
    end
    
    after(:all) do
      @fb_page.destroy
    end
  end 
end
