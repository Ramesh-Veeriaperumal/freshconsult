require 'spec_helper'
load 'spec/support/conference_transfer_spec_helper.rb'
RSpec.configure do |c|
  c.include ConferenceTransferSpecHelper
end

RSpec.describe Freshfone::ConferenceTransferController  do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    create_test_freshfone_account
    @request.host = @account.full_domain
    @freshfone_call.reload unless @freshfone_call.blank?
    @conf_call_meta.reload unless @conf_call_meta.blank?
    @freshfone_child_call.reload unless @freshfone_child_call.blank?
  end

  after(:all) do
    @freshfone_call.destroy unless @freshfone_call.blank?
    @conf_call_meta.destroy unless @conf_call_meta.blank?
  end

  it 'should render valid transfer twiml on for an incoming call which is in-progress' do
    create_freshfone_conf_call('CTRANSFER')
    request.env["HTTP_ACCEPT"] = "application/json"
    log_in(@agent)
    post :initiate_transfer, initiate_transfer_params
    expect(json).to eql({:status => "transferred"})
  end

  it 'should render valid transfer twiml on for an incoming call which is on-hold' do
    create_freshfone_conf_call('CTRANSFER',12)
    request.env["HTTP_ACCEPT"] = "application/json"
    log_in(@agent)
    post :initiate_transfer, initiate_transfer_params
    expect(json).to eql({:status => "transferred"})
  end

  it 'should render valid transfer twiml on for an outgoing call which is in-progress' do
    create_freshfone_conf_call('CTRANSFER',1,2)
    request.env["HTTP_ACCEPT"] = "application/json"
    log_in(@agent)
    post :initiate_transfer, initiate_transfer_params("", "true")
    expect(json).to eql({:status => "transferred"})
  end

  it 'should render valid transfer twiml on for an outgoing call which is on-hold' do
    create_freshfone_conf_call('CTRANSFER',12,2)
    request.env["HTTP_ACCEPT"] = "application/json"
    log_in(@agent)
    post :initiate_transfer, initiate_transfer_params("", "true")
    expect(json).to eql({:status => "transferred"})
  end
# End of initiate_transfer

  it "should render valid transfer success twiml for an incoming call" do 
    transfer_agent = add_test_agent(@account)
    create_freshfone_user(1,transfer_agent)
    stub_twilio_call(:get, [:update])
    parent_call = create_freshfone_conf_call('CTRANSFER')
    child_call = create_conf_child_call('CTRANSFERCHILD',parent_call,transfer_agent)
    create_freshfone_conf_call_meta(child_call, [{:id=>transfer_agent.id,:ff_user_id => transfer_agent.id,:name=>transfer_agent.name,:device_type=>:browser,:call_sid =>'CAeab765499b16de80d428196f8c59ef28'}])
    Freshfone::Providers::Twilio.any_instance.stubs(:dequeue)
    set_twilio_signature("freshfone/conference_transfer/transfer_success?call=#{parent_call.id}", transfer_success_params(parent_call.id).except("call"))
    post :transfer_success, transfer_success_params(parent_call.id)
    Freshfone::Providers::Twilio.any_instance.unstub(:dequeue)
    Twilio::REST::Calls.any_instance.unstub(:get)
    expect(response.body).to match(/Conference/)
    expect(response.body).to match(/Room_1_CTRANSFERCHILD/)
  end

  it "should render valid empty twiml for an incoming call when there is an exception in transfer success" do 
    @account.freshfone_calls.destroy_all
    transfer_agent = add_test_agent(@account)
    create_freshfone_user(1,transfer_agent)
    stub_twilio_call(:get, [:update])
    parent_call = create_freshfone_conf_call('CTRANSFER')
    child_call = create_conf_child_call('CTRANSFERCHILD',parent_call,transfer_agent)
    create_freshfone_conf_call_meta(child_call, [{:id=>transfer_agent.id,:ff_user_id => transfer_agent.id,:name=>transfer_agent.name,:device_type=>:browser,:call_sid =>'CTRANSFER'}])
    Freshfone::Notifier.any_instance.stubs(:disconnect_other_agents).raises(StandardError.new("Unknown Error"))
    set_twilio_signature("freshfone/conference_transfer/transfer_success?call=#{parent_call.id}", transfer_success_params(parent_call.id).except("call"))
    post :transfer_success, transfer_success_params(parent_call.id)
    Twilio::REST::Calls.any_instance.unstub(:get)
    expect(response.body).to match(/Response/)
  end

  it "should return valid twiml(play music) for transfer wait" do 
    transfer_agent = add_test_agent(@account)
    create_freshfone_user(1,transfer_agent)
    parent_call = create_freshfone_conf_call('CTRANSFER')
    child_call = create_conf_child_call('CTRANSFERCHILD',parent_call,transfer_agent)
    Freshfone::Providers::Twilio.any_instance.stubs(:dequeue)
    create_freshfone_conf_call_meta(child_call, [{:id=>transfer_agent.id,:ff_user_id => transfer_agent.id,:name=>transfer_agent.name,:device_type=>:browser,:call_sid =>'CAeab765499b16de80d428196f8c59ef28'}])
    set_twilio_signature("freshfone/conference_transfer/transfer_agent_wait", transfer_agent_wait_params)
    post :transfer_agent_wait, transfer_agent_wait_params
    expect(response.body).to match(/Play/)
    Freshfone::Providers::Twilio.any_instance.unstub(:dequeue)
  end

  it "should successfully complete transfer" do 
    transfer_agent = add_test_agent(@account)
    create_freshfone_user(1,transfer_agent)
    parent_call = create_freshfone_conf_call('CTRANSFER')
    child_call = create_conf_child_call('CTRANSFERCHILD',parent_call,transfer_agent)
    create_freshfone_conf_call_meta(child_call, [{:id=>transfer_agent.id,:ff_user_id => transfer_agent.id,:name=>transfer_agent.name,:device_type=>:browser,:call_sid =>'CAeab765499b16de80d428196f8c59ef28'}])
    Freshfone::Call.any_instance.stubs(:disconnect_source_agent)
    Freshfone::Providers::Twilio.any_instance.stubs(:dequeue)
    post :complete_transfer, {:CallSid => "CTRANSFER"}
    expect(json).to eql({:status => "success"})
    Freshfone::Providers::Twilio.any_instance.unstub(:dequeue)
    Freshfone::Call.any_instance.unstub(:disconnect_source_agent)

  end

  it "should resume call and respond proper json message on resume transfer" do 
    transfer_agent = add_test_agent(@account)
    create_freshfone_user(1,transfer_agent)
    parent_call = create_freshfone_conf_call('CTRANSFER1',12)#on-hold
    child_call = create_conf_child_call('CTRANSFERCHILD1',parent_call,transfer_agent)
    create_freshfone_conf_call_meta(child_call, [{:id=>transfer_agent.id,:ff_user_id => transfer_agent.id,:name=>transfer_agent.name,:device_type=>:browser,:call_sid =>'CAeab765499b16de80d428196f8c59ef28'}])
    Freshfone::Providers::Twilio.any_instance.stubs(:dequeue)
    post :resume_transfer, {:CallSid => "CTRANSFERCHILD1"}
    expect(json).to eql({:status => "unhold_initiated"})
    Freshfone::Providers::Twilio.any_instance.unstub(:dequeue)
  end

  it "should respond with proper twiml message for transfer_source_redirect" do 
    @account.freshfone_calls.destroy_all
    transfer_agent = add_test_agent(@account)
    create_freshfone_user(1,transfer_agent)
    parent_call = create_freshfone_conf_call('CTRANSFER',12)#on-hold
    child_call = create_conf_child_call('CTRANSFERCHILD',parent_call,transfer_agent)
    set_twilio_signature("freshfone/conference_transfer/transfer_source_redirect", {:CallSid => 'CTRANSFER'})
    post :transfer_source_redirect, { :CallSid => 'CTRANSFER' }
    expect(response.body).to match(/Conference/)
    expect(response.body).to match(/Room_1_CTRANSFER/)

  end

  it "should respond with proper json message for cancel transfer" do 
    @account.freshfone_calls.destroy_all
    transfer_agent = add_test_agent(@account)
    create_freshfone_user(1,transfer_agent)
    parent_call = create_freshfone_conf_call('CTRANSFER2',12)#on-hold
    child_call = create_conf_child_call('CTRANSFERCHILD2',parent_call,transfer_agent)
    create_freshfone_conf_call_meta(child_call, [{:id=>transfer_agent.id,:ff_user_id => transfer_agent.id,:name=>transfer_agent.name,:device_type=>:browser,:call_sid =>'CAeab765499b16de80d428196f8c59ef28'}])
    Freshfone::Notifier.any_instance.stubs(:terminate_api_call)
    Freshfone::Providers::Twilio.any_instance.stubs(:dequeue)
    post :cancel_transfer, {:CallSid => "CTRANSFERCHILD2", :call => child_call.id}
    expect(json).to eql({:status => "unhold_initiated"})
    Freshfone::Providers::Twilio.any_instance.unstub(:dequeue)
    Freshfone::Notifier.any_instance.unstub(:terminate_api_call)
  end


end