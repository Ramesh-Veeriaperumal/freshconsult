require 'spec_helper'
include FreshfoneCallSpecHelper

describe Freshfone::CallController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    @account.update_attributes(:full_domain => "http://play.ngrok.com")
    @request.host = @account.full_domain
    
    create_test_freshfone_account
    create_freshfone_user
  end

  after(:each) do
    @account.freshfone_users.find(@freshfone_user).destroy
  end

  it 'should retrieve caller data for the phone number' do
    log_in(@agent)
    setup_caller_data

    get :caller_data, { :PhoneNumber => @caller_number }
    call_meta = json[:call_meta].reject{|k,v| v.blank?}
    call_meta.keys.should be_eql([:number, :group])
  end

  it 'should update call status and user presence' do
    set_twilio_signature("freshfone/call/in_call?agent=#{@agent.id}", in_call_params.except("agent"))
    create_freshfone_call("CSATH")

    post :in_call, in_call_params
    
    freshfone_user = @account.freshfone_users.find_by_user_id(@agent)
    freshfone_user.should be_busy
    freshfone_call = @account.freshfone_calls.find_by_call_sid("CSATH")
    freshfone_call.should be_inprogress
    xml.should be_eql({:Response=>nil})
  end

  it 'should update call status on direct dial success callback' do 
    set_twilio_signature("freshfone/call/direct_dial_success?direct_dial_number=9994269753", 
      direct_dial_params.except("direct_dial_number"))
    create_freshfone_call("CDIRECT")

    post :direct_dial_success, direct_dial_params
    freshfone_call = @account.freshfone_calls.find_by_call_sid("CDIRECT")
    freshfone_call.should be_inprogress
    freshfone_call.direct_dial_number.should be_eql("9994269753")
    xml.should be_eql({:Response=>nil})
  end

  it 'should update agent presence on successful call transfer' do 
    set_twilio_signature("freshfone/call/call_transfer_success?call_back=false&source_agent=#{@agent.id}", call_transfer_params)
    create_freshfone_call("CTRANSFER")
    @freshfone_user.update_attributes(:presence => 2)

    post :call_transfer_success, call_transfer_params.merge({"call_back" => "false", "source_agent" => @agent.id})
    freshfone_call = @account.freshfone_calls.find_by_call_sid("CTRANSFER")
    freshfone_call.should be_inprogress
    freshfone_user = @account.freshfone_users.find_by_user_id(@agent) 
    freshfone_user.should be_online
  end

  it 'should not update agent presence on returning transfer' do
    set_twilio_signature("freshfone/call/call_transfer_success?call_back=true&agent=#{@agent.id}", call_transfer_params)
    create_freshfone_call("CTRANSFER")
    @freshfone_user.update_attributes(:presence => 2)

    post :call_transfer_success, call_transfer_params.merge({"call_back" => "true", "agent" => @agent.id})
    freshfone_call = @account.freshfone_calls.find_by_call_sid("CTRANSFER")
    freshfone_user = @account.freshfone_users.find_by_user_id(@agent) 
    freshfone_user.should be_busy
  end

  it 'should update call status as completed for normal end call' do
    set_twilio_signature('freshfone/call/status', status_params)
    create_call_for_status
    
    post :status, status_params
    freshfone_call = @account.freshfone_calls.find(@freshfone_call)
    freshfone_call.should be_completed
    xml.should be_eql({:Response => nil})
  end

  it 'should update call status as completed for forwarded calls' do
    set_twilio_signature('freshfone/call/status', status_params)
    set_active_call_in_redis({:answered_on_mobile => true})
    create_call_for_status
    
    post :status, status_params
    freshfone_call = @account.freshfone_calls.find(@freshfone_call)
    freshfone_call.should be_completed
    xml.should be_eql({:Response => nil})
  end

  it 'should populate call details for normal end call' do  
    set_twilio_signature('freshfone/call/status', status_params)
    create_call_for_status
    key = "FRESHFONE_ACTIVE_CALL:#{@account.id}:CA67b4b4052a6c79d662a27edda3615449"
    controller.set_key(key, {:agent => @agent.id}.to_json)
    post :status, status_params
    freshfone_call = @account.freshfone_calls.find(@freshfone_call)
    freshfone_call.should be_completed
  end

  it 'should update call status on force termination' do
    set_twilio_signature('freshfone/call/status?force_termination=true', status_params)
    create_call_for_status
    key = "FRESHFONE_ACTIVE_CALL:#{@account.id}:CA67b4b4052a6c79d662a27edda3615449"
    controller.set_key(key, {:agent => @agent.id}.to_json)
    post :status, status_params.merge(:force_termination => true)
    freshfone_call = @account.freshfone_calls.find(@freshfone_call)
    freshfone_call.should be_completed
  end

  it 'should render twiml with batched clients ids for batched calls' do
    set_twilio_signature('freshfone/call/status?batch_call=true', status_params.merge({"DialCallStatus" => 'busy'}))
    create_call_for_status
    setup_batch
    post :status, status_params.merge({:batch_call => true, "DialCallStatus" => 'busy'}) 
    tear_down BATCH_KEY
    xml[:Response][:Dial][:Client].should be_eql(@dummy_users.map{|u| u.id.to_s})
  end

  it 'should clear any batch key for non batched calls' do
    set_twilio_signature('freshfone/call/status?batch_call=true', status_params.merge({"DialCallStatus" => 'busy'}))
    create_call_for_status
    post :status, status_params.merge({:batch_call => true, "DialCallStatus" => 'busy'}) 
    xml[:Response][:Say].should_not be_blank
  end

  it 'should render non availability message for missed calls' do
    set_twilio_signature('freshfone/call/status', status_params.merge({"DialCallStatus" => 'busy'}))
    create_call_for_status
    post :status, status_params.merge({"DialCallStatus" => 'busy'})
    xml[:Response][:Say].should_not be_blank
  end

  it 'should update agent presence and call status on successful call transfer' do 
    set_twilio_signature("freshfone/call/status?call_back=false&source_agent=#{@agent.id}", status_params)
    @freshfone_user.update_attributes(:presence => 2)
    create_call_for_status
    setup_call_for_transfer

    post :status, status_params.merge({"call_back" => "false", "source_agent" => @agent.id})
    tear_down TRANSFER_KEY
    JSON.parse(assigns[:transferred_calls]).last.should be_eql(@freshfone_call.user_id.to_s)
  end

  it 'should transfer the call back to source agent' do 
    set_twilio_signature("freshfone/call/status?call_back=false&outgoing=false&source_agent=#{@agent.id}", status_params.merge({"DialCallStatus" => 'in-progress'}))
    @freshfone_user.update_attributes(:presence => 2)
    create_call_for_status
    setup_call_for_transfer
    controller.stubs(:current_number).returns(@number)
    post :status, status_params.merge({"call_back" => "false", "outgoing" => "false", "source_agent" => @agent.id, "DialCallStatus" => 'in-progress'})
    tear_down TRANSFER_KEY
    xml[:Response][:Dial][:Client].should be_eql(@agent.id.to_s)
  end

  # it 'should return an empty twiml on status exception' do 
  #   set_twilio_signature('freshfone/call/status', status_params)
  #   create_call_for_status
  #   controller.stubs(:call_forwarded?).raises(ActiveRecord::RecordNotFound)
  #   controller.stubs(:record_not_found)
  #   post :status, status_params
  #   xml.should be_eql({:Response=>nil})
  # end

  it 'should return a json validating the number of client calls for current user' do
    log_in(@agent)
    get :inspect_call, {:call_sid => "CDUMMY"}
    tear_down CLIENT_CALL
    json.should be_eql({:can_accept => 1})
  end

end