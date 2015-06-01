require 'spec_helper'

#Test cases for xml api calls to time entries.
RSpec.describe Helpdesk::TimeSheetsController do
  self.use_transactional_fixtures = false

  TIME_ENTRY_XML_ATTRIBS = ["billable", "created_at", "executed_at", "id", "note", 
    "start_time", "timer_running", "updated_at", "user_id", "workable_type", "ticket_id",
     "agent_name", "time_spent", "agent_email", "customer_name", "contact_email"]


  before(:all) do
    @test_ticket = create_ticket({ :status => 2 }, create_group(@account, {:name => "Time sheets"}))
    @group = @account.groups.first
    @test_agent = add_test_agent(@account,{})
  end
  
  before(:each) do
    request.host = @account.full_domain
    http_login(@agent)
  end

  it "should create a time entry" do 
    params = time_entry_params
    post :create, {:time_entry => params, :ticket_id => @test_ticket.display_id, :format => 'xml'}, :content_type => 'application/xml'
    #api impl gives out 200 status, change this when its fixed to return 201
    result = parse_xml(response)
    expected = (response.status === 200)&& (compare(result["time_entry"].keys, TIME_ENTRY_XML_ATTRIBS, {}).empty?)
    expected.should be(true)
  end

  it "should show an existing time entry for the ticket" do
    time_sheet = create_test_time_entry({}, @test_ticket)
    get :show, {:id => time_sheet.id, :ticket_id=>@test_ticket.display_id, :format => 'xml'}
    result = parse_xml(response)
    expected = (response.status === 200) && (compare(result["time_entry"].keys, TIME_ENTRY_XML_ATTRIBS, {}).empty?)
    expected.should be(true)
  end

  it "should update an existing time entry" do
    params = time_entry_params
    time_sheet = create_test_time_entry({}, @test_ticket)
    params["billable"] = false #updating billable to false
    put :update, {:id => time_sheet.id, :ticket_id=>@test_ticket.display_id, :time_entry => params  ,:format => 'xml'}
    result = parse_xml(response)
    expected = (response.status === 200) && (compare(result["time_entry"].keys, TIME_ENTRY_XML_ATTRIBS, {}).empty?)
    expected.should be(true)
  end

  it "should delete an existing time entry" do
    time_sheet = create_test_time_entry({}, @test_ticket)
    delete :destroy, {:id => time_sheet.id, :format => 'xml'}
    response.status.should be_eql(200)   
  end
  
  it "should show an all time entries for the ticket" do
    time_sheet = create_test_time_entry({}, @test_ticket)
    get :index, { :ticket_id => @test_ticket.display_id, :format => 'xml'}
    result = parse_xml(response)
    expected = (response.status === 200) && (compare(result["time_entries"].first.keys, TIME_ENTRY_XML_ATTRIBS, {}).empty?)
    expected.should be(true)
  end

  it "should start/stop  (toggle) the time entry" do
    time_sheet = create_test_time_entry({}, @test_ticket)
    put :toggle_timer, {:id => time_sheet.id, :ticket_id => @test_ticket.display_id, :format => 'xml'}
    result = parse_xml(response)
    expected = (response.status === 200)  && (compare(result["time_entry"].keys, TIME_ENTRY_XML_ATTRIBS, {}).empty?)
    expected.should be(true)
  end

   it "should show time entries for the filter criteria (billable)" do
    time_sheet = create_test_time_entry({}, @test_ticket)
    get :index, { :billable => true, :start_date => 2.days.ago.to_s(:db) , :format => 'xml'}
    result = parse_xml(response)
    expected = (response.status === 200) && (compare(result["time_entries"].first.keys, TIME_ENTRY_XML_ATTRIBS, {}).empty?)
    expected.should be(true)
  end
  

  def time_entry_params
    { "note"=>Faker::Lorem.sentence(3), 
      "hhmm"=>10.4, 
      "user_id" => @test_agent.id,
      "billable" => true
    }
  end

end