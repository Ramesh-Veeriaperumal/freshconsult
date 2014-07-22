require "spec_helper"

describe AgentsController do

	let(:params) { {:format => "json"} }
	
 	before(:each) do
    request.host = @account.full_domain
	  request.user_agent = "Freshdesk_Native_Android"
	  request.accept = "application/json"
	  request.env['HTTP_AUTHORIZATION'] =  ActionController::HttpAuthentication::Basic.encode_credentials(@agent.single_access_token,"X")
	  request.env['format'] = 'json'
  end

  it "should return an agent object with all valid attributes" do
    user = add_test_agent(@account)
    get :show, params.merge!(:id => user.agent.id)
    user_json = json_response['user'].map{|res| res[0]}
    required_attributes = ["id","avatar_url","name","email", "company_name", "phone", "mobile", "job_title", "user_time_zone", "twitter_id"]
    required_attributes.all? { |attribute| user_json.include?(attribute)}.should be_true
  end
end