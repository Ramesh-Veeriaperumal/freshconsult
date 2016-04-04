require 'spec_helper'

RSpec.describe Helpdesk::SurveysController do

  self.use_transactional_fixtures = false

  before(:each) do
    request.host = @account.full_domain
    http_login(@agent)
  end

  it "should be able to rate(Survey) a ticket" do
    @test_ticket = create_ticket()
    post :rate, {:rating=>1, :ticket_id=>@test_ticket.display_id, :feedback=>"Keep up the good work -John", :format => 'xml'}, :content_type => 'application/xml'
    result = parse_xml(response)
    expected = (response.status === 200)  && compare(result['survey_result'].keys, APIHelper::SURVEY_ATTRIBS, {}).empty?
    expected.should be(true)
  end
  
  it "should be able to fetch the survey results for the ticket." do
    @test_ticket = create_ticket()
    get :index, {:ticket_id=>@test_ticket.display_id, :format => 'xml'}, :content_type => 'application/xml'
    result = parse_xml(response)
    expected = (response.status === 200)
    expected.should be(true)
  end
end