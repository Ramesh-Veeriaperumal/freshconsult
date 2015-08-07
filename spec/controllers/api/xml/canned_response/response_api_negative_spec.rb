require 'spec_helper'

describe Helpdesk::CannedResponses::ResponsesController do
	setup :activate_authlogic
	self.use_transactional_fixtures = false

	before(:all) do
		@now = (Time.now.to_f*1000).to_i
		@group = create_group(@account, {:name => "Response grp #{@now}"})
		@folder_id = @account.canned_response_folders.find_by_is_default(true).id
		@test_response_1 = create_response( {:title => "New Canned_Responses Hepler",:content_html => "DESCRIPTION: New Canned_Responses Hepler",
			:visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents]} )
	end

	before(:each) do
		@request.env['HTTP_REFERER'] = '/admin/canned_responses/folders'
		http_login(@agent)
	end

	after(:all) do
		@test_response_1.destroy
	end

	it "should not update a Canned Responses with empty title" do
		put :update, {
			:id => @test_response_1.id,
			:admin_canned_responses_response => {:title => "",
				:content_html => "Updated Canned_Responses without title",
				:visibility => {:user_id => @agent.id, 
								:visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents], 
								:group_id => @group.id}
			},
			:new_folder_id => @folder_id,
			:folder_id => "#{@test_response_1.folder_id}",
			:format => 'xml'
		}
		name_blank?(response).should be true
		error_status?(response.status).should be true
		canned_response = @account.canned_responses.find_by_id(@test_response_1.id)
		canned_response.title.should eql("New Canned_Responses Hepler")
		canned_response.title.should_not eql ""
		canned_response.content_html.should_not eql("Updated Canned_Responses without title")
	end

		def error_status?(status)
			status == 422
		end

		def name_blank?(response)
			result = parse_xml(response)
			["Title is too short (minimum is 3 characters)"].include?(result["errors"]["error"])
		end
end