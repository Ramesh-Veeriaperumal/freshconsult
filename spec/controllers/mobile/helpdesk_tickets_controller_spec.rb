require 'spec_helper'

describe Helpdesk::TicketsController do
  self.use_transactional_fixtures = false

  before(:all) do
    @test_ticket = create_ticket({ :status => 2 }, create_group(@account, {:name => "Tickets"}))
    body = Faker::Lorem.paragraph
    create_note({:source => @test_ticket.source,
                               :ticket_id => @test_ticket.id,
                               :body => body,
                               :user_id => @agent.id})
    @group = @account.groups.first
  end

  before(:each) do
    request.host = @account.full_domain
    request.user_agent = "Freshdesk_Native_Android"
    request.accept = "application/json"
    request.env['HTTP_AUTHORIZATION'] =  ActionController::HttpAuthentication::Basic.encode_credentials(@agent.single_access_token,"X")
    request.env['format'] = 'json'
  end

  it "should get the single ticket" do
    get 'show', { :format => "json", :id => @test_ticket.display_id }
    json_response.should include("helpdesk_ticket","user","subscription","ticket_properties","account","note")
    json_response["helpdesk_ticket"].should include("id","spam","is_closed","deleted","ticket_sla_status","source_name","conversation_count")
    json_response["note"].should include("user","schema_less_note","source","id","private","formatted_created_at")
    json_response["user"].should include("can_delete_ticket","can_edit_ticket_properties","can_reply_ticket","can_forward_ticket","can_edit_conversation")
    json_response["helpdesk_ticket"]["ticket_properties"].each do |ticket_property|
      ticket_property.should include("ticket_field")
      ticket_property["ticket_field"].should include("field_type","field_name","dom_type","required","required_for_closure","label")
    end
  end

  it "should get all the tickets" do
    get 'index', {"wf_order_type"=>"desc", "wf_order"=>"created_at", "format"=>"json", "filter_name"=>"new_and_my_open"}
    json_response.should include("ticket","top_view","user")
    json_response["ticket"].each do|ticket|
      ticket.should include("display_id","id","priority","status","status_name","subject","updated_at","ticket_subject_style",
                            "ticket_current_state","ticket_sla_status","requester_name","responder_name")
    end
    json_response["top_view"].each do |top_view|
      top_view.should include("id","name","default")
    end
    json_response["user"].should include("id","display_name","can_delete_ticket","can_view_contacts","can_delete_contact",
                                          "can_edit_ticket_properties","can_view_solutions")
  end

  it "should execute a scenario" do
    scenario = @account.scn_automations.find_by_name("Mark as Feature Request")
    post 'execute_scenario', { "scenario_id" => scenario.id, "id" => @test_ticket.display_id , "format" => "json"}
    json_response.should include("success","success_message","id")
    json_response["success"].should be_true
    json_response["success_message"].should be_eql("Scenario Executed")
  end

  it "should delete ticket forever" do
    @test_ticket.deleted = 1
    @test_ticket.save!
    delete 'delete_forever', {"id"=> @test_ticket.display_id, "format"=>"json"}
    json_response.should include("success","success_message")
    json_response["success"].should be_true
    json_response["success_message"].should be_eql("1 ticket was deleted.")
  end
end
