require 'spec_helper'

describe Helpdesk::CannedResponsesController do
	setup :activate_authlogic
	self.use_transactional_fixtures = false

		before(:all) do
			@now = (Time.now.to_f*1000).to_i
			@test_response_1 = create_response( {:title => "Recent Canned_Responses",:content_html => Faker::Lorem.paragraph,
				:visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents]} )
			@test_response_2 = create_response( {:title => "Recent Canned_Responses Hepler #{@now}",:content_html => Faker::Lorem.paragraph,
				:visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents]} )
			@test_response_3 = create_response( {:title => "Recent Canned_Responses Only_me #{@now}",:content_html => "CONTENT: Canned_Responses Only_me #{@now}",
				:visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me]} )
		end

		before(:each) do
			log_in(@agent)
		end

		it "should go to insert CR index page" do
			get :index
			response.should render_template("helpdesk/tickets/components/_ticket_canned_responses.html.erb")
		end

		it "should search the canned responses" do
			get :search, :search_string => "Recent", :format => 'js'
			response.body.should =~ /#{@test_response_1.title}/
			response.body.should_not =~ /#{@test_response_2.title}/
			response.body.should =~ /#{@test_response_3.title}/
		end

		it "should view the canned responses" do
			ticket = create_ticket({:status => 2})
			post :show, :ca_resp_id => @test_response_3.id, :id => ticket.display_id
			response.body.should =~ /CONTENT: Canned_Responses Only_me #{@now}/
			response.body.should_not =~ /#{@test_response_1.content_html}/
		end
	end
