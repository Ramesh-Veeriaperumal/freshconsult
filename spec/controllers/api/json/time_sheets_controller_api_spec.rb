require 'spec_helper'

#Test cases for json api calls to time entries.
RSpec.describe Helpdesk::TimeSheetsController do
  self.use_transactional_fixtures = false


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
    post :create, {:time_entry => params, :ticket_id => @test_ticket.display_id, :format => 'json'}, :content_type => 'application/json'
    #api impl gives out 200 status, change this when its fixed to return 201
    result = parse_json(response)
    expected = (response.status === 200) && (compare(result["time_entry"].keys, APIHelper::TIME_ENTRY_ATTRIBS, {}).empty?)
    expected.should be(true)
  end

  it "should show an existing time entry for the ticket" do
    params = time_entry_params
    time_sheet = create_test_time_entry({}, @test_ticket)
    get :show, {:id => time_sheet.id, :ticket_id=>@test_ticket.display_id, :format => 'json'}
    result = parse_json(response)
    expected = (response.status === 200) && (compare(result["time_entry"].keys, APIHelper::TIME_ENTRY_ATTRIBS, {}).empty?)
    expected.should be(true)
  end

  it "should update an existing time entry" do
    params = time_entry_params
    time_sheet = create_test_time_entry({}, @test_ticket)
    params["billable"] = false #alos updating billable to false
    put :update, {:id => time_sheet.id, :ticket_id=>@test_ticket.display_id, :time_entry => params  ,:format => 'json'}
    result = parse_json(response)
    expected = (response.status === 200) && (compare(result["time_entry"].keys, APIHelper::TIME_ENTRY_ATTRIBS, {}).empty?)
    expected.should be(true)
  end

  # Delete time entry api(json) is failing in production. throwing 500 error. Need to be
  # fixed. The test case below is correct (checked with xml api). Uncomment after fixing it.
  # it "should delete an existing time entry" do
  #   time_sheet = create_test_time_entry({}, @test_ticket)
  #   delete :destroy, {:id => time_sheet.id, :format => 'json'}
  #   response.status.should be_eql(200)   
  # end
  it "should delete an existing time entry" do
    time_sheet = create_test_time_entry({}, @test_ticket)
    delete :destroy, {:id => time_sheet.id, :format => 'json'}
    response.status.should be_eql(200)   
  end
  
  it "should show an all time entries for the ticket" do
    time_sheet = create_test_time_entry({}, @test_ticket)
    get :index, { :ticket_id => @test_ticket.display_id, :format => 'json'}
    result = parse_json(response)
    expected = (response.status === 200) && (compare(result.first["time_entry"].keys, APIHelper::TIME_ENTRY_ATTRIBS, {}).empty?)
    expected.should be(true)
  end

  it "should start/stop  (toggle) the time entry" do
    time_sheet = create_test_time_entry({}, @test_ticket)
    put :toggle_timer, {:id => time_sheet.id, :ticket_id => @test_ticket.display_id, :format => 'json'}
    result = parse_json(response)
    expected = (response.status === 200)  && (compare(result["time_entry"].keys, APIHelper::TIME_ENTRY_ATTRIBS, {}).empty?)
    expected.should be(true)
  end
  
   it "should show time entries for the filter criteria (billable)" do
    time_sheet = create_test_time_entry({}, @test_ticket)
    get :index, { :billable => true, :start_date => 2.days.ago.to_s(:db) , :format => 'json'}
    result = parse_json(response)
    expected = (response.status === 200) && (compare(result.first["time_entry"].keys, APIHelper::TIME_ENTRY_ATTRIBS, {}).empty?)
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