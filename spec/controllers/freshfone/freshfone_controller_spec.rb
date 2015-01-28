require 'spec_helper'
load 'spec/support/freshfone_spec_helper.rb'
include FreshfoneSpecHelper
include Redis::RedisKeys
include Redis::IntegrationsRedis

describe FreshfoneController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false
  
  before(:all) do
    @account.freshfone_calls.destroy_all
  end

  before(:each) do
    create_test_freshfone_account
    @request.host = @account.full_domain
  end

  #Spec for Freshfone base controller
  it 'should custom-validate request from Twilio and allow call' do
    set_twilio_signature('freshfone/voice', incoming_params)
    post :voice, incoming_params
    response.body.should_not be_blank
    xml.should have_key(:Response)
  end

  it 'should fail on extremely low freshfone credit' do
    set_twilio_signature('freshfone/voice', incoming_params)
    @account.freshfone_credit.update_attributes(:available_credit => 0.1)
    post :voice, incoming_params
    xml.should be_eql({:Response=>{:Reject=>nil}})
  end

  it 'should fail on missing freshfone feature' do
    set_twilio_signature('freshfone/voice', incoming_params)
    @account.features.freshfone.destroy
    post :voice, { :format => "html" }
    response.body.should include('freshfone enabled validation failed')
  end

  it 'should redirect to login when non-twilio-aware methods are called by not logged in users' do
    get :dashboard_stats, { :format => "json" }
    expected = {
      :require_login => true
    }.to_json
    response.body.should be_eql(expected)
  end
  #End spec for freshfone base controller. 
  #Change this to contexts


  #Spec for actual freshfone_controller
  it 'should render valid twiml on ivr_flow' do  
    set_twilio_signature('freshfone/ivr_flow?menu_id=0', ivr_flow_params.except("menu_id"))
    post :ivr_flow, ivr_flow_params
    response.body.should_not be_blank
    xml.should have_key(:Response)
  end

  it 'should render valid twiml on voice_fallback' do  
    set_twilio_signature('freshfone/voice_fallback', fallback_params)
    post :voice_fallback, fallback_params
    xml.should have_key(:Response)
  end

  it 'should render valid json on dashboard_stats' do
    log_in(@agent)
    key = NEW_CALL % {:account_id => @account.id}
    add_to_set(key, "1234")
    get :dashboard_stats, { :format => "json" }
    expected = {
      :available_agents => @account.freshfone_users.online_agents.count,
      :active_calls => get_count_from_integ_redis_set(key)
    }.to_json
    response.body.should be_eql(expected)
  end

  it "must be routable to the dial_check action" do
     { :get => "freshfone/dial_check" }.should be_routable
  end

  it 'should render valid json on dial_check' do
    log_in(@agent)
    get :dial_check, { :phone_number => "+918754693849" } 
    result = JSON.parse(response.body).symbolize_keys
    result.has_key?(:status)
    result.has_key?(:code)
  end

  it 'should respond with ok status' do
    log_in(@agent)
    get :dial_check, { :phone_number => "+918754693849" }
    result = JSON.parse(response.body).symbolize_keys
    result.should include(:status => "ok") 
  end

  it 'should respond with low credit status' do
    log_in(@agent)
    @account.freshfone_credit.update_attributes(:available_credit => 0.1)
    get :dial_check, { :phone_number => "+918754693849" } 
    result = JSON.parse(response.body).symbolize_keys
    result.should include(:status => "low_credit") 
  end

  it 'should respond with dial restricted country status' do
    log_in(@agent)
    get :dial_check, { :phone_number => "+8558754693849" } 
    result = JSON.parse(response.body).symbolize_keys
    result.should include(:status => "dial_restricted_country") 
  end

  it "must throw exception if country is not present" do
    log_in(@agent)
    get :dial_check, { :phone_number => "+2478754693849" } 
    begin
      expect(response).to raise_error
    rescue
    end
  end

  it 'should apply indian number fix for incorrect caller id' do
    modified_params = incoming_params
    modified_params["From"] = "+166174802401"
    set_twilio_signature('freshfone/voice', modified_params)
    post :voice, modified_params
    response.body.should_not be_blank
    xml.should have_key(:Response)
  end

  it 'should add a call note to an existing ticket' do
    log_in(@agent)
    ticket = create_ticket({:status => 2})
    freshfone_call = create_freshfone_call
    create_freshfone_user if @agent.freshfone_user.blank?
    params = { :id => ticket.id, :ticket => ticket.display_id, :call_log => "Sample freshfone note", 
               :CallSid => freshfone_call.call_sid, :private => false, :call_history => "false" }
    post :create_note, params
    assigns[:current_call].note.notable.id.should be_eql(ticket.id) 
    assigns[:current_call].note.body.should =~ /Sample freshfone note/
  end

  it 'should create a new call ticket' do
    log_in(@agent)
    freshfone_call = create_freshfone_call
    build_freshfone_caller
    create_freshfone_user if @agent.freshfone_user.blank?
    customer = create_dummy_customer
    params = { :CallSid => freshfone_call.call_sid, :call_log => "Sample Freshfone Ticket", 
               :custom_requester_id => customer.id, :ticket_subject => "Call with Oberyn", :call_history => "false"}
    post :create_ticket, params
    assigns[:current_call].ticket.subject.should be_eql("Call with Oberyn")
  end

  it 'should not add a call note to an existing ticket on failed ticket creation' do
    log_in(@agent)
    ticket = create_ticket({:status => 2})
    freshfone_call = create_freshfone_call
    create_freshfone_user if @agent.freshfone_user.blank?
    params = { :id => ticket.id, :ticket => ticket.display_id, :call_log => "Sample freshfone note", 
               :CallSid => freshfone_call.call_sid, :private => false, :call_history => "false" }
    
    save_note = stub()
    save_note.stubs(:save).returns(false)
    controller.stubs(:build_note).returns(save_note)

    post :create_note, params
    Freshfone::Call.find(freshfone_call.id).note.should be_nil
  end

  it 'should not create a new call ticket on failed ticket creation' do
    log_in(@agent)
    freshfone_call = create_freshfone_call
    build_freshfone_caller
    create_freshfone_user if @agent.freshfone_user.blank?
    customer = create_dummy_customer
    params = { :CallSid => freshfone_call.call_sid, :call_log => "Sample Freshfone Ticket", 
               :custom_requester_id => customer.id, :ticket_subject => "Call with Oberyn", :call_history => "false"}
    
    save_ticket = stub()
    save_ticket.stubs(:save).returns(false)
    controller.stubs(:build_ticket).returns(save_ticket)

    post :create_ticket, params
    Freshfone::Call.find(freshfone_call.id).ticket.should be_nil
  end

end