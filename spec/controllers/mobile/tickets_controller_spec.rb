require 'spec_helper'

describe Mobile::TicketsController do
    self.use_transactional_fixtures = false
    let(:params) { {:format =>'json'} }

    before(:all) do
	    @test_ticket = create_ticket({ :status => 2, :subject => "Sample subject" , :description => "Sample description"}, create_group(@account, {:name => "Tickets"}))
  	end

    before(:each) do
	    @request.user_agent = "Freshdesk_Native_Android"
	    @request.accept = "application/json"
	    @request.env['HTTP_AUTHORIZATION'] = "Basic #{Base64.encode64("#{@agent.single_access_token}:X").delete("\r\n")}"
	    @request.format = "json"
  	end

  	it "gets the ticket properties" do
  		get :ticket_properties, params
  		properties = ["email", "cc_emails", "subject", "ticket_type", "source", "status", "priority", "group_id", "responder_id", "description_html"]
  		ticket_properties = json_response.map{ |ticket_field| ticket_field["ticket_field"]["field_name"] }
		ticket_properties.should include_all(["email", "cc_emails", "subject", "ticket_type", "source", "status", "priority", "group_id", "responder_id", "description_html"]);
	end


	it "returns an array" do
		get :load_reply_emails, params
		json_response.should be_an_instance_of(Array) 
	end

	it "attributes are valid" do
		get :load_reply_emails, params
		json_response.each do |support_email|
			support_email.count.should be_eql(2)
			support_email[0].should be_an_instance_of(Fixnum)
			support_email[1].should be_an_instance_of(String)
		end	
	end
end