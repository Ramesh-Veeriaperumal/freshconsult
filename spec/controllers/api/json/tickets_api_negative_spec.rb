require 'spec_helper'

describe Helpdesk::TicketsController do

  self.use_transactional_fixtures = false
  include APIAuthHelper

  before(:each) do
    request.host = RSpec.configuration.account.full_domain
    http_login(RSpec.configuration.agent)
  end

  it "should create a ticket" do
    
  	post :create, {:helpdesk_ticket => {:subject => Faker::Lorem.words(10).join(" "),
          :description => Faker::Lorem.paragraph,
          :email => Faker::Internet.email,
          :priority => "Lower" },:format => 'json'}, :content_type => 'application/json'
    response.status.should be_eql('406 Not Acceptable')
  end

  it "should update a ticket" do
  	new_ticket = create_ticket({:status => 2})
  	put :update, { :helpdesk_ticket => {:status => 3, :priority => "Higher" },:format => 'json',:id => new_ticket.display_id }, :content_type => 'application/json'
    result = parse_json(response)
    expected = (response.status == 200 && result["errors"].first == "Priority should be a valid priority")
    expected.should be(true)
 	end

  it "should throw invalid domain error for an invalid request" do
    get :show, {:id => 1000000000, :format => 'json'}, :content_type => 'application/json'
    result =  parse_json(response)
    result["errors"]["error"].should be_eql("Record Not Found")
  end
end
