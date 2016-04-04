require 'spec_helper'

RSpec.describe Helpdesk::TicketsController do

  self.use_transactional_fixtures = false

  before(:each) do
    request.host = @account.full_domain
    http_login(@agent)
  end

  it "should create a ticket" do
    
  	post :create, {:helpdesk_ticket => {:subject => Faker::Lorem.words(10).join(" "),
          :description => Faker::Lorem.paragraph,
          :email => Faker::Internet.email,
          :priority => "Lower" },:format => 'xml'}, :content_type => 'application/xml'
    result = parse_xml(response)
    expected = (response.status == 200 && result["errors"]['error'] == "Priority should be a valid priority")
    expected.should be(true)
  end
  
  it "should update a ticket" do
  	new_ticket = create_ticket({:status => 2})
  	put :update, { :helpdesk_ticket => {:status => 3, :priority => "Higher" },:format => 'xml',:id=>new_ticket.display_id }, :content_type => 'application/xml'
    result = parse_xml(response)
    expected = (response.status == 200 && result["errors"]['error'] == "Priority should be a valid priority")
    expected.should be(true)
 	end

  it "should throw invalid domain error for an invalid request" do
    get :show, {:id => 1000000000, :format => 'xml'}, :content_type => 'application/xml'
    result =  parse_xml(response)
    result["errors"]["error"].should be_eql("Record Not Found")
  end
end
