require 'spec_helper'

describe Helpdesk::DashboardController do
	integrate_views
	setup :activate_authlogic
	self.use_transactional_fixtures = false

	before(:all) do
		@forum_category = create_test_category
		@forum = create_test_forum(@forum_category)
		@id = @account.activities.last.id
	end

	before(:each) do
		login_admin
	end

	it "should display the Dashboard page" do
		xhr :get, :index
		response.body.should =~ /#{@forum.name}/
		response.body.should =~ /#{@forum_category.name}/
		response.should be_success
	end

	it "should display the activity_list without id" do
		topic = create_test_topic(@forum)
		get :activity_list
		response.body.should =~ /Recent Activity/
		response.body.should =~ /#{topic.title}/
		response.body.should =~ /#{@forum.name}/
		response.body.should =~ /#{@forum_category.name}/
		response.should be_success
	end

	it "should display the activity_list with activity_id" do
		cr_folder = create_cr_folder({:name => Faker::Name.name})
		get :activity_list, :activity_id => @id
		response.body.should_not =~ /#{cr_folder.name}/
		response.body.should =~ /#{@forum_category.name}/
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