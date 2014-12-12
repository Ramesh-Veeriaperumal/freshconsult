require 'spec_helper'

describe Helpdesk::CannedResponses::FoldersController do
	integrate_views
	setup :activate_authlogic
	self.use_transactional_fixtures = false

	before(:each) do
		login_admin
	end

	it "should not create a new folder with less than 3 characters" do
		post :create, { :admin_canned_responses_folder => {:name => "cr"}, :format => 'xml' }
		name_blank?(response).should be_true
		error_status?(response.status).should be_true
		@account.canned_response_folders.find_by_name("cr").should be_nil
	end

		def error_status?(status)
			status =~ /422 Unprocessable Entity/ 
		end

		def name_blank?(response)
			result = parse_xml(response)
			["Name is too short (minimum is 3 characters)"].include?(result["errors"]["error"])
		end
end