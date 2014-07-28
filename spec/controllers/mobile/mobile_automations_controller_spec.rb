require "spec_helper"

describe Mobile::AutomationsController do
    self.use_transactional_fixtures = false

    let(:params) { {:format =>'json'} }
    before(:each) do
    	api_login
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