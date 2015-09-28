require 'spec_helper'

RSpec.configure do |c|
  c.include FacebookHelper
end

describe Integrations::Hootsuite::TicketsController do
	setup :activate_authlogic
	self.use_transactional_fixtures = false
	
	before(:all) do
     @hs_params = {:pid=>"4095315", :uid=>"10788857",:ts=>"1434097760", :token=>"ba9be29c71f33fb151acd8b0b64a2891597e1077bb3c407a475f47677c6d2c92418c5fb0a30fbbd8b8dc3f3cbc1b3adbeac50c4a4f9bd6230d7a411d79ba285b"}
     Integrations::HootsuiteRemoteUser.create(
        :configs => {:pid => @hs_params[:pid]},
        :account_id => @agent.account_id,
        :remote_id => @hs_params[:uid])
     @ticket = create_ticket({:status => 2,:responder_id => @agent.id})
	end

	before(:each) do
		log_in(@agent)
	end

	 it "should update ticket properties" do
	 	custom_param = @hs_params.merge(:id => @ticket.display_id,:helpdesk_ticket => {
	 		:priority => 4,
	 		:status => 2,
	 		:source => 5,
	 		:responder_id => 1
	 		})
	 	put :update ,custom_param
	 	ticket = @account.tickets.find_by_display_id(@ticket.display_id)
	 	ticket.priority.should eql 4
	 	ticket.status.should eql 2
	 	ticket.source.should eql 5
	 	ticket.responder_id.should eql 1
	 end

	it "should add note" do
		post :add_note ,@hs_params.merge(:id => @ticket.display_id,:isPrivate => false,:message => "test note",:format => 'js')
		response.should render_template "integrations/hootsuite/tickets/note"
		Helpdesk::Ticket.find_by_display_id(@ticket.display_id).notes.last.note_body.body.should include "test note"
	end

	it "should add reply" do
		post :add_reply ,@hs_params.merge(:id => @ticket.display_id,
			 :from =>" Test Account <support@localhost.freshdesk-dev.com> ",
			 :message => "test reply",
			 :format => 'js'
			 )
		response.should render_template "integrations/hootsuite/tickets/note"
		Helpdesk::Ticket.find_by_display_id(@ticket.display_id).notes.last.note_body.body.should include "test reply"
	end

	it "should append social reply" do
		get :append_social_reply ,@hs_params.merge(:id => @ticket.display_id,:format => 'js')
		response.should render_template "integrations/hootsuite/tickets/note"
	end

	it "should create tickets from twitter stream" do
		@account.make_current
		@handle = create_test_twitter_handle(@account)
    	@default_stream = @handle.default_stream
    	@custom_stream = create_test_custom_twitter_stream(@handle)
    	twitter_params = sample_params_fd_item("#{(Time.now.utc.to_f*100000).to_i}", @stream_id, SEARCH_TYPE[:custom])
    	custom_params = @hs_params.merge(
    		:helpdesk_ticket => {
	    		:subject => " test subject",
	    		:ticket_body_attributes => {:description_html => "test description"},
	    		:twitter_id => @default_stream.name,
	    		:responder_id => @agent.id
	    		},
    		:tweet_id => twitter_params[:item][:feed_id],
    		:twitter_handle_id =>@handle.id
    		)
    	post :create,custom_params
    	tweet = @account.tweets.find_by_tweet_id(custom_params[:tweet_id])
    	tweet.should_not be_nil
    	tweet.is_ticket?.should be_truthy
	end

	it "should create tickets from facebook stream" do
	    @fb_page = create_test_facebook_page(@account)
	    thread_id = Time.now.utc.to_i
	    actor_id = thread_id + 1
	    msg_id = thread_id + 2
	    sample_dm = sample_dm_threads(thread_id, actor_id, msg_id)
	    Koala::Facebook::API.any_instance.stubs(:get_connections).returns(sample_dm)
	    fb_message = Facebook::Graph::Message.new(@fb_page)
	    fb_message.fetch_messages
	    fb_profile_id = @account.facebook_posts.find_by_post_id(msg_id).postable.requester.fb_profile_id
	    post_id = Time.now.utc.to_i
	    Facebook::Core::Util.stubs(:facebook_user).returns(@agent)
    	custom_params = @hs_params.merge(
    		:helpdesk_ticket => {
	    		:subject => "test subject",
	    		:ticket_body_attributes => {:description_html => "test description"},
	    		:name => Faker::Name.name,
	    		:responder_id => @agent.id
	    		},
    		:post_id => post_id,
    		:fb_profile => {:id => fb_profile_id,:name => Faker::Name.name},
    		:fb_page_id => @fb_page.id
    		)
    	post :create,custom_params
    	post = @account.facebook_posts.find_by_post_id(post_id)
    	post.should_not be_nil
    	post.is_ticket?.should be_truthy
	end

	 it "should go to the index page" do
	 	get :show ,@hs_params.merge(:id => @account.facebook_posts.last.postable.display_id)
	 	response.should render_template "integrations/hootsuite/tickets/show"
	 end
end