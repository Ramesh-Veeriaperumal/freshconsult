require 'spec_helper'

describe TicketFieldsController do
	self.use_transactional_fixtures = false
	include APIAuthHelper

	before(:each) do
		request.host = @account.full_domain
		http_login(@agent)
	end

	it "should list all the ticket_fields" do
        get :index, :format => 'json'
        result = parse_json(response)
        expected = (response.status == 200) && (compare(result.first["ticket_field"].keys, APIHelper::TICKET_FIELDS_ATTRIBS, {}).empty?) 
        expected.should be(true)
	end

end
		
