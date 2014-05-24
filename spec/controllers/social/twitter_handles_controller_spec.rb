require 'spec_helper'

describe Social::TwitterHandlesController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @agent_role = @account.roles.find_by_name("Agent")
  end

  before(:each) do
    login_admin
  end

  describe "GET #index" do

    context "without api exception" do
      it "should be successful" do
        get :index

        response.should render_template("social/twitter_handles/index.html.erb")
        session["request_token"].present?.should be_true
        session["request_secret"].present?.should be_true
      end
    end

    context "with api exception" do
      it "should redirect if exception arises" do
        TwitterWrapper.any_instance.stubs(:request_tokens).raises(Timeout::Error)
        get :index

        response.should redirect_to 'admin/home'
      end
    end

  end


  describe "GET #authdone" do

    it "should redirect to existing handle if handle already exists" do
      Social::TwitterHandle.destroy_all
      twt_handler = create_test_twitter_handle(@account, true)
      TwitterWrapper.any_instance.stubs(:auth).returns(twt_handler)

      get :authdone
      response.should redirect_to "social/twitters/#{twt_handler.id}/edit"
    end

    it "should redirect to new handle if it doesn't exists" do
      Social::TwitterHandle.destroy_all
      twt_handler = Factory.build(:twitter_handle, :screen_name => Faker::Name.name.downcase, :access_token => Faker::Lorem.characters(10),
                                  :access_secret => Faker::Lorem.characters(10), :capture_dm_as_ticket => 1, :capture_mention_as_ticket => 1,
                                  :twitter_user_id => rand(100000000))
      TwitterWrapper.any_instance.stubs(:auth).returns(twt_handler)

      get :authdone
      twt_handler = @account.twitter_handles.find_by_screen_name(twt_handler.screen_name)
      response.should redirect_to "social/twitters/#{twt_handler.id}/edit"
    end

    it "should redirect to social/twitters if exception arise" do
      TwitterWrapper.any_instance.stubs(:auth).raises(Errno::ECONNRESET)
      get :authdone
      response.should redirect_to "social/twitters"
    end

  end


  describe "GET #feed" do

    it "if no handles present should redirect to /admin/twitter" do
      Social::TwitterHandle.destroy_all

      get :feed
      response.should redirect_to 'social/twitters'
    end

    it "if handles preset should render feed page" do
      twt_handler = create_test_twitter_handle(@account, true)

      get :feed
      response.should render_template("social/twitter_handles/feed.html.erb")
    end

  end

  describe "GET #twitter_search" do

    it "should search for keyword and respond with json for Index page" do
      twt_handler = create_test_twitter_handle(@account, true)
      json_data = {'attrs' => {'statuses' => [], 'search_metadata' => {}} }
      Twitter::Client.any_instance.stubs(:search).returns(json_data)

      get :twitter_search, {:q => 'test', :handle => 0}
      response.body.should be_eql(json_data.to_json)
    end

    it "should search for keyword and respond with json for show more page" do
      twt_handler = create_test_twitter_handle(@account, true)
      json_data = {'attrs' => {'statuses' => [], 'search_metadata' => {}} }
      Twitter::Client.any_instance.stubs(:search).returns(json_data)

      get :twitter_search, {:q => 'test', :handle => 0, :max_id => 10}
      response.body.should be_eql(json_data.to_json)
    end

    it "should search for keyword and respond with json for show new page" do
      twt_handler = create_test_twitter_handle(@account, true)
      json_data = {'attrs' => {'statuses' => [], 'search_metadata' => {}} }
      Twitter::Client.any_instance.stubs(:search).returns(json_data)

      get :twitter_search, {:q => 'test', :handle => 0, :since_id => 10}
      response.body.should be_eql(json_data.to_json)
    end

    it "should catch exception and respond with json" do
      twt_handler = create_test_twitter_handle(@account, true)
      Twitter::Client.any_instance.stubs(:search).raises(Twitter::Error::TooManyRequests)

      get :twitter_search, {:q => 'test', :handle => 0, :since_id => 10}
      JSON.parse(response.body).class.should be_eql(Hash)
    end

  end


  describe "DELETE #destroy" do

    it "should delete and redirect" do
      Social::TwitterHandle.destroy_all
      twt_handler = create_test_twitter_handle(@account, true)
      delete :destroy, :id => twt_handler.id

      handle = @account.twitter_handles.find_by_id(twt_handler.id)
      handle.present?.should be_false
      response.should redirect_to 'social/twitters'
    end

  end

  describe "GET #tweet_exists" do

    it "Check for tweet exists" do
      get :tweet_exists, :tweet_ids => rand(100)
      body = JSON.parse(response.body)
      body.class.should be_eql(Hash)
    end

  end

  describe "GET #create_twicket" do

    it "should create tweet as ticket " do
      Social::TwitterHandle.destroy_all
      twt_handler = create_test_twitter_handle(@account, true)

      Twitter::Client.any_instance.stubs(:status).returns(Twitter::Tweet)
      Twitter::Tweet.stubs(:in_reply_to_status_id).returns(nil)

      twitter_id = Faker::Name.name
      subject = Faker::Lorem.characters(100)
      get :create_twicket, {
        'helpdesk_tickets'=> {
          'subject' => subject,
          'product_id' => 'null',
          'twitter_id' => twitter_id,
          'tweet_attributes' => {
            'tweet_id' => rand(100000000),
            'twitter_handle_id' => twt_handler.id
          },
          'ticket_body_attributes' => {
            'description' => Faker::Lorem.characters(100)
          }
        },
        'profile_image' => {
          'url' => Faker::Internet.domain_name
        }
      }

      response.should render_template '_create_twicket'
      @account.contacts.find_by_twitter_id(twitter_id).present?.should be_true
      @account.tickets.find_by_subject(subject).present?.should be_true
    end

    it "should create first tweet as ticket and second tweet as note " do
      Social::TwitterHandle.destroy_all
      twt_handler = create_test_twitter_handle(@account, true)

      #========================first tweet start====================================
      Twitter::Client.any_instance.stubs(:status).returns(Twitter::Tweet)
      Twitter::Tweet.stubs(:in_reply_to_status_id).returns(nil)

      twitter_id = Faker::Name.name
      subject    = Faker::Lorem.characters(100)
      tweet_id   = rand(100000000)
      get :create_twicket, {
        'helpdesk_tickets'=> {
        'subject' => subject,
        'product_id' => 'null',
        'twitter_id' => twitter_id,
        'tweet_attributes' => {
          'tweet_id' => tweet_id,
          'twitter_handle_id' => twt_handler.id
        },
        'ticket_body_attributes' => {
          'description' => Faker::Lorem.characters(100)
        }
      },
      'profile_image' => {
        'url' => Faker::Internet.domain_name
      }
    }
      #========================first tweet end====================================

      ft = @account.tweets.find_by_tweet_id(tweet_id)
      Twitter::Client.any_instance.stubs(:status).returns(Twitter::Tweet)
      Twitter::Tweet.stubs(:in_reply_to_status_id).returns(ft.tweet_id)

      twitter_id = Faker::Name.name
      subject = Faker::Lorem.characters(100)
      note_tweet_id = rand(100000000)

      get :create_twicket, {
        'helpdesk_tickets'=> {
          'subject' => subject,
          'product_id' => 'null',
          'twitter_id' => twitter_id,
          'tweet_attributes' => {
            'tweet_id' => note_tweet_id,
            'twitter_handle_id' => twt_handler.id
          },
          'ticket_body_attributes' => {
            'description' => Faker::Lorem.characters(100)
          }
        },
        'profile_image' => {
          'url' => Faker::Internet.domain_name
        }
      }

      response.should render_template '_create_twicket'
      @account.contacts.find_by_twitter_id(twitter_id).present?.should be_true
      ticket = Helpdesk::Ticket.find_by_id(ft.tweetable_id)
      ticket.notes.present?.should be_true
      ticket.notes.last.tweet.tweet_id.should be_eql(note_tweet_id)
    end

  end

  describe "GET #edit" do

    it "should be successful when updating form" do
      Social::TwitterHandle.destroy_all
      twt_handler = create_test_twitter_handle(@account, true)

      put :update,  {
        :social_twitter_handle => {
          :search_keys => ["@#{twt_handler.screen_name}"],
          :capture_mention_as_ticket => twt_handler.capture_mention_as_ticket,
          :capture_dm_as_ticket => twt_handler.capture_dm_as_ticket,
          :dm_thread_time => '86400'
        },
        :id => twt_handler.id
      }

      handle =  @account.twitter_handles.find_by_id(twt_handler.id)
      handle.should be_an_instance_of(Social::TwitterHandle)
      handle.search_keys.first.should be_eql("@#{twt_handler.screen_name}")
      handle.capture_mention_as_ticket.should be_true

      handle.dm_thread_time.should be_eql(86400)
    end
  end
end
