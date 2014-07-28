require "spec_helper"

describe Helpdesk::CannedResponsesController do
	self.use_transactional_fixtures = true

	let(:params) { {:format =>'json'} }

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
		api_login
	end

	it "should return canned responses array" do
		get :show, params.merge!(:ca_resp_id => @test_response_3.id , :id => 1)
		response.body.should include("CONTENT: Canned_Responses") 
	end

	it "should get all the canned responses folders" do
		get :index, params
		json_response.should be_an_instance_of(Array)
		json_response.each do |res|
			res["response"].keys.should include("content","folder","id")
			res["response"]["folder"].keys.should include("account_id","created_at","is_default","name","id")
		end
	end
end