require 'spec_helper'

describe Admin::ContactFieldsController do
	self.use_transactional_fixtures = false
	include APIAuthHelper

	before(:each) do
		request.host = @account.full_domain
		http_login(@agent)
	end

	it "should list all the contact_fields" do
        get :index, :format => 'json'
        result = parse_json(response)
        expected = (response.status == 200) && (compare(result.first["contact_field"].keys,APIHelper::CONTACT_FIELDS_ATTRIBS,{}).empty?) 
        expected.should be(true)
	end

end
		
