require 'spec_helper'

describe ChatsController do
	setup :activate_authlogic
	self.use_transactional_fixtures = false
	
	before(:each) do
		login_admin
	end

	it "should create ticket " do
		post :create_ticket , :ticket =>{:name =>"test", :email=>"test@test.com", :subject=>"testing", :content=>"test is a kind of test of a test" }
		temp = JSON.parse(response.body)
		temp["status"].should eql true
		temp["ticket_id"].should be_a_kind_of(Numeric)
	end

	it "should add note" do
		fakeTicket=create_ticket()
		post :add_note , :ticket_id => fakeTicket.display_id, :note => "test is always a test"
		temp = JSON.parse(response.body)
		temp["status"].should eql true
		temp["ticket_id"].should eql fakeTicket.display_id
	end

end