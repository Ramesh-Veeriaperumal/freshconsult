require 'spec_helper'

describe Integrations::Cti::CustomerDetailsController do
	integrate_views
	setup :activate_authlogic
	self.use_transactional_fixtures = false
	
	before(:all) do
    @cust_mob = "0123456789"
    @customer = @account.users.create(:name => "Gaurav Sachan", :email => "gaurav@freshdesk.com", :phone => @cust_mob)
    @test_ticket = create_ticket({ :status => 2,:requester_id => @customer.id })
    @recUrl = "http://testurl.com"
	end

	before(:each) do
		log_in(@agent)
	end

	it "should create ticket" do
		post :create_ticket , {:ticket => {
			:subject => "test subject",
			:email => @customer.email,
			:description => "test description",
			:recordingUrl => @recUrl
		}}
		@customer.tickets[1].nil?.should be_false
	end

	it "should create ticket for new users" do
		new_user_mob = "12345"
		post :create_ticket , {:ticket => {
			:subject => "test subject",
			:number => new_user_mob,
			:description => "test description",
			:recordingUrl => @recUrl,
		}}
		@account.tickets.last.requester.mobile.should eql new_user_mob
	end

	it "should create note for existing ticket" do
		post :create_note , {
			:ticketId => @test_ticket.id,
			:msg => "test notes",
			:recordingUrl => @recUrl
		}
		@test_ticket.notes.nil?.should be_false
	end

	it "should fetch user details and tickets of existing users" do
		get :fetch , {
			:user => {:mobile => @cust_mob},
			:agent => {:email => @agent.email}
		}
		resp=JSON.parse(response.body)
		resp["data"]["mobile"].should eql @cust_mob
	end

	it "should create agent as contact if it does not exist" do
		get :fetch , {
			:user => {:mobile => @cust_mob},
			:agent => {:email => "test@email.com"}
		}
		usr = User.find(:first,:conditions => {:email => "test@email.com"})
		usr.nil?.should be_false
	end
	it "auth success for valid session" do
		get :get_session , {
			:email => @agent.email,
			:format => "json"
		}
		resp=JSON.parse(response.body)
		sessionId = resp["sessionId"]
		post :verify_session,{
			:requestXml => "<request><command>login</command><userId>#{@agent.email}</userId><password>#{sessionId}</password></request>"
		}
		a=Hash.from_xml(response.body)
		a["response"]["status"].should eql "success"
	end

	it "auth failed for incorrect session" do
		sessionId = "wrongsession"
		post :verify_session,{
			:requestXml => "<request><command>login</command><userId>#{@agent.email}</userId><password>#{sessionId}</password></request>"
		}
		a=Hash.from_xml(response.body)
		a["response"]["status"].should eql "failed"
	end
end