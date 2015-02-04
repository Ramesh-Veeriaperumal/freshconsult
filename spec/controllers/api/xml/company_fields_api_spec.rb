require 'spec_helper'

describe Admin::CompanyFieldsController do
	self.use_transactional_fixtures = false
	include APIAuthHelper

	before(:each) do
		request.host = @account.full_domain
		http_login(@agent)
	end

	it "should list all the company_fields" do
        get :index, :format => 'xml'
        result = parse_xml(response)
        debugger
        expected = (response.status == "200 OK") &&(compare(result["company_fields"].first.keys,APIHelper::COMPANY_FIELDS_ATTRIBS,{}).empty?) 
        expected.should be(true)
	end

end
		
