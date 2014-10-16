require 'spec_helper'

RSpec.describe AgentsController do
  self.use_transactional_fixtures = false
	
  let(:params) { {:format => "json"} }
	
 	before(:each) do
    api_login
  end

  it "should return an agent object with all valid attributes" do
    user = add_test_agent(@account)
    get :show, params.merge!(:id => user.agent.id)
    user_json = json_response['user'].map{|res| res[0]}
    required_attributes = ["id","avatar_url","name","email", "company_name", "phone", "mobile", "job_title", "user_time_zone", "twitter_id"]
    required_attributes.all? { |attribute| user_json.include?(attribute)}.should be true
  end
end