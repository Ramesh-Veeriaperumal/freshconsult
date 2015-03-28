require 'spec_helper'

describe TicketFieldsController do
	self.use_transactional_fixtures = false
	include APIAuthHelper

	before(:each) do
		request.host = @account.full_domain
		http_login(@agent)
	end

	it "should list all the ticket_fields" do
        get :index, :format => 'xml'
        result = parse_xml(response)
        expected = (response.status == 200) &&(compare(result["helpdesk_ticket_fields"].first.keys,(APIHelper::TICKET_FIELDS_ATTRIBS - ['nested_ticket_fields', 'import_id']),{}).empty?) 
        expected.should be(true)
	end

end
		
