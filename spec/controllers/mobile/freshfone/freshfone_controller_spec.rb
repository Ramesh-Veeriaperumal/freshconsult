require 'spec_helper'

RSpec.describe FreshfoneController do
	self.use_transactional_fixtures = false

	before(:all) do
       @account.freshfone_calls.destroy_all
  	end

	before(:each) do
	   create_test_freshfone_account
	   api_login
	end

	it "should create a new ticket for a call" do
	   freshfone_call = create_freshfone_call
	   build_freshfone_caller
	   create_freshfone_user if @agent.freshfone_user.blank?
	   customer = create_dummy_customer
	   params = { "format" => "json", :CallSid => freshfone_call.call_sid, :call_log => "Sample Freshfone Ticket", 
	               :custom_requester_id => customer.id, :ticket_subject => "Call with Oberyn", :call_history => "false"}
	   post :create_ticket, params
	   json_response.should include("success","ticket")
	   json_response["ticket"].should include("display_id","subject","status_name","priority")
	   json_response["success"].should be true
	end
end