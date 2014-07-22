require "spec_helper"

describe Mobile::AutomationsController do
    self.use_transactional_fixtures = false

    let(:params) { {:format =>'json'} }
    before(:each) do
    	request.host = @account.full_domain
	    request.user_agent = "Freshdesk_Native_Android"
	    request.accept = "application/json"
	    request.env['HTTP_AUTHORIZATION'] =  ActionController::HttpAuthentication::Basic.encode_credentials(@agent.single_access_token,"X")
	    request.env['format'] = 'json'
  	end

	it "should be an array" do 
		get :index, params
		json_response.should be_an_instance_of(Array) 
	end

	it 	"attributes should be valid" do
		get :index, params
		json_response.each do |ticket|
		  	ticket.should have_key("va_rule")
		    ticket['va_rule'].should include("name","description","id");
		end
	end

end