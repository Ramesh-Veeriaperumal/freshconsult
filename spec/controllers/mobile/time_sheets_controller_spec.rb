require 'spec_helper'

describe Helpdesk::TimeSheetsController do	
  self.use_transactional_fixtures = false

 	before(:each) do
    api_login
  end

  before(:all) do
    @test_ticket = create_ticket({ :status => 2 }, create_group(@account, {:name => "Tickets"}))
  end

  it "should create a timesheet" do
    user = add_test_agent(@account)
    post :create, {
      "time_entry" => {
        "executed_at" => DateTime.now.strftime("%d %b, %Y"), 
        "workable_id" => @test_ticket.id, 
        "billable"    => "1", 
        "note"        => "Mobile", 
        "user_id"     => user.id, 
        "hhmm"        => "11:12"
      }, 
      "ticket_id" => @test_ticket.display_id, 
      "format"=>"json"
    }
    json_response.should include("success")
    json_response["success"].should be true
  end

  it "should get timesheets for a ticket" do
    get :index, {"ticket_id"=>@test_ticket.display_id, "format"=>"json"}
    json_response[0].should include("time_sheet")
    json_response[0]["time_sheet"].should include("billable","executed_at","id","note","time_spent","user_id","agent_name")
  end

  it "should delete a timesheet entry for a ticket" do
    now = (Time.now.to_f*1000).to_i
    time_sheet = FactoryGirl.build(:time_sheet, :user_id => @agent.id,
                                            :workable_id => @test_ticket.id,
                                            :account_id => @account.id,
                                            :billable => 1,
                                            :note => "Note for edit")
    time_sheet.save
    delete :destroy, {"id"=>"#{time_sheet.id}", "format"=>"json"}
    json_response["success"].should be true
  end

end