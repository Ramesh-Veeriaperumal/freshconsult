require 'spec_helper'

describe Helpdesk::DashboardController do
	integrate_views
	setup :activate_authlogic
	self.use_transactional_fixtures = false

	before(:all) do
		@id = @account.activities.last.id
	end

	before(:each) do
		login_admin
	end

	it "should display the Dashboard page" do
		xhr :get, :index
		response.body.should =~ /Announcements/
		response.body.should =~ /This is a sample ticket/
		response.body.should =~ /Test Account Forums/
		response.should be_success
	end

	it "should display the activity_list without id" do
		get :activity_list
		response.body.should =~ /Recent Activity/
		response.body.should =~ /Feature Requests/
		response.body.should =~ /Tips and Tricks/
		response.should be_success
	end

	it "should display the activity_list with activity_id" do
		get :activity_list, :activity_id => @id
		response.body.should =~ /Report a problem/
		response.body.should =~ /Announcements/
		response.should be_success
	end

	it "should display the latest_activities of the user" do
		new_ticket = create_ticket({:status => 2})
		get :latest_activities, :previous_id => @id
		response.body.should =~ /#{new_ticket.subject}/
		response.should be_success
	end

	it "should display the latest ticket summary" do
		get :latest_summary
		response.body.should =~ /Ticket summary/
		response.body.should =~ /Overdue/
		response.body.should =~ /Due Today/
		response.body.should =~ /On Hold/
		response.should be_success
	end
end