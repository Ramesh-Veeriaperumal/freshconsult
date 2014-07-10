   
require 'spec_helper'

describe Helpdesk::ConversationsController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @handle = create_test_twitter_handle(@account)
    @handle.update_attributes(:capture_dm_as_ticket => true)
  end
   
  before(:each) do
    log_in(@agent)
  end
   
   
  describe "POST #twitter" do
    # added only for DM ticket. Replying for a tweet ticket has been covered already in twitter controller spec
    it "should send a reply to a DM ticket" do
      # create a DM ticket
      sample_dm = sample_twitter_dm("#{(Time.now.utc.to_f*100000).to_i}", Faker::Lorem.words(3), Time.zone.now.ago(3.days))
      twitter_dm = Twitter::DirectMessage.new(sample_dm)
      twitter_dm_array = [twitter_dm]
      Twitter::REST::Client.any_instance.stubs(:direct_messages).returns(twitter_dm_array)
      Social::Workers::Twitter::DirectMessage.perform({:account_id => @account.id})
      tweet = Social::Tweet.find_by_tweet_id(sample_dm[:id])
      tweet.should_not be_nil
      tweet.is_ticket?.should be_true
      
      # replying to a DM ticket
      ticket = tweet.get_ticket
      dm_text = Faker::Lorem.sentence(3)
      dm_reply_params = {
        :id => (Time.now.utc.to_f*100000).to_i,
        :id_str => "#{(Time.now.utc.to_f*100000).to_i}",
        :recipient_id_str => rand.to_s[2..11],
        :text => dm_text ,
        :created_at => "#{Time.zone.now}"
      }
      sample_dm_reply = Twitter::DirectMessage.new(dm_reply_params)
      Twitter::REST::Client.any_instance.stubs(:direct_message_create).returns(sample_dm_reply)
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
      dm = Social::Tweet.find_by_tweet_id(dm_reply_params[:id])
      dm.should_not be_nil
      dm.is_note?.should be_true
      note_body = dm.tweetable.note_body.body
      note_body.should eql(dm_text)
      tweet.destroy
      dm.destroy
    end
  end
  
  after(:all) do
    @handle.destroy
  end
end