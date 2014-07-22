require "spec_helper"

describe Helpdesk::CannedResponsesController do
	self.use_transactional_fixtures = true

	let(:params) { {:format =>'json'} }

	before(:all) do
		@now = (Time.now.to_f*1000).to_i
		@test_response_1 = create_response( {:title => "Recent Canned_Responses",:content_html => Faker::Lorem.paragraph,
			:folder_id => 1, :user_id => @agent.id, :visibility => 1, :group_id => 1  } )
		@test_response_2 = create_response( {:title => "Recent Canned_Responses Hepler #{@now}",:content_html => Faker::Lorem.paragraph,
			:folder_id => 1, :user_id => @agent.id, :visibility => 2, :group_id => 1  } )
		@test_response_3 = create_response( {:title => "Recent Canned_Responses Only_me #{@now}",:content_html => "CONTENT: Canned_Responses Only_me #{@now}",
			:folder_id => 1, :user_id => @agent.id, :visibility => 3, :group_id => 1  } )
	end

	before(:each) do
		request.host = @account.full_domain
		request.user_agent = "Freshdesk_Native_Android"
		request.accept = "application/json"
		request.env['HTTP_AUTHORIZATION'] =  ActionController::HttpAuthentication::Basic.encode_credentials(@agent.single_access_token,"X")
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