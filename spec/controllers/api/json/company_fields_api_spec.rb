require 'spec_helper'

describe Admin::CompanyFieldsController do
	self.use_transactional_fixtures = false
	include APIAuthHelper

	before(:each) do
		request.host = @account.full_domain
		http_login(@agent)
	end

	it "should list all the company_fields" do
        get :index, :format => 'json'
        result = parse_json(response)
        attributes = (APIHelper::COMPANY_FIELDS_ATTRIBS - ['field_type']).insert(APIHelper::COMPANY_FIELDS_ATTRIBS.index('field_options')+1, 'field_type')
        expected = (response.status == 200) && (compare(result.first["company_field"].keys, attributes, {}).empty?) 
        expected.should be(true)
	end

end
		
