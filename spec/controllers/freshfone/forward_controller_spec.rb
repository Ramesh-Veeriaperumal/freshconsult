require 'spec_helper'

RSpec.describe Freshfone::ForwardController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false
  
  before(:all) do
    @account.freshfone_calls.destroy_all
  end

  before(:each) do
    create_test_freshfone_account
    @request.host = @account.full_domain
    @account.freshfone_calls.destroy_all
    @account.freshfone_callers.delete_all
    create_freshfone_user
    log_in @agent
  end

  it 'should initiate the call for users who are in mobile' do
    create_freshfone_call
    params = { :call => @freshfone_call.id, :agent_id => @agent.id }
    set_twilio_signature("freshfone/forward/initiate?call=#{@freshfone_call.id}&agent_id=#{@agent.id}")
    post :initiate, params
    expect(xml).to be_truthy
    expect(xml).to have_key(:Response)
  end

  it 'should initiate the transfer without any exception when transferred from some other agent' do
    create_call_family
    create_call_meta(@parent_call.children.last)
    stub_twilio_queues
    @parent_call.update_column(:call_status, Freshfone::Call::CALL_STATUS_HASH[:'on-hold'])
    set_twilio_signature("freshfone/forward/transfer_initiate?call=#{@parent_call.id}&agent_id=#{@agent.id}&transferred_from=#{@agent.id}")
    post :transfer_initiate, { :call => @parent_call.id, :transferred_from => @agent.id, :agent_id => @agent }
    expect(xml).to be_truthy
    expect(xml).to have_key(:Response)
    expect(xml[:Response]).to have_key(:Dial)
    expect(xml[:Response][:Dial]).to have_key(:Conference)
    Twilio::REST::Queues.any_instance.unstub(:get)
  end

  it 'should update the conference sid while waiting for transfer' do
    create_freshfone_call
    params = incoming_params.merge('ConferenceSid' => 'ConSid')
    set_twilio_signature("freshfone/forward/transfer_wait", params)
    post :transfer_wait, params
    @freshfone_call.reload
    expect(@freshfone_call.conference_sid).to eq('ConSid')
    expect(xml).to be_truthy
    expect(xml).to have_key(:Response)
    expect(xml[:Response]).to have_key(:Play)
  end

  it 'should send an empty twiml on transfer complete to the mobile number' do
    create_call_family
    @parent_call.update_column(:call_status, Freshfone::Call::CALL_STATUS_HASH[:'on-hold'])
    params = { :CallSid => @parent_call.call_sid, :CallStatus => Freshfone::Call::CALL_STATUS_HASH[:answered] }
    set_twilio_signature("freshfone/forward/transfer_complete", params)
    post :transfer_complete, params
    expect(xml).to be_truthy
    expect(xml).to have_key(:Response)
  end

  it 'should send an empty comment for the completion of forwarding  to the mobile number' do
    create_freshfone_call
    create_freshfone_user
    create_call_meta
    create_pinged_agents
    stub_twilio_queues
    params = { :CallSid => @freshfone_call.call_sid, :CallStatus => 'accepted', :agent => @agent.id }
    set_twilio_signature("freshfone/forward/complete?agent=#{@agent.id}",params.except(:agent))
    post :complete, params
    expect(xml).to be_truthy
    expect(xml).to have_key(:Response)
    Twilio::REST::Queues.any_instance.unstub(:get)
  end

  it 'should make the agent wait while transferring to mobile from ivr direct dial' do
    create_freshfone_call
    call = mock
    call.stubs(:sid).returns('DDSid')
    Twilio::REST::Calls.any_instance.stubs(:create).returns(call)
    params = { :CallSid => @freshfone_call.call_sid, :ConfereceSid => 'ConSid' }
    set_twilio_signature("freshfone/forward/direct_dial_wait", params)
    post :direct_dial_wait, params
    expect(xml).to be_truthy
    expect(xml).to have_key(:Response)
    expect(xml[:Response]).to have_key(:Play)
    expect(xml[:Response][:Play]).to match(/.mp3/)
    Twilio::REST::Calls.any_instance.unstub(:create)
  end


  it 'should give an empty twiml on exception while waiting in direct dial' do
    create_freshfone_call
    Freshfone::Notifier.any_instance.stubs(:ivr_direct_dial).raises(StandardError, 'This is an exceptional message')
    params = { :CallSid => @freshfone_call.call_sid, :ConfereceSid => 'ConSid' }
    set_twilio_signature("freshfone/forward/direct_dial_wait", params)
    post :direct_dial_wait, params
    expect(xml).to be_truthy
    expect(xml).to have_key(:Response)
    Freshfone::Notifier.any_instance.unstub(:ivr_direct_dial)
  end

  it 'should update the call accordingly when the direct dial from ivr is successful' do
    create_freshfone_call
    stub_twilio_call(:get, [:update])
    set_twilio_signature("freshfone/forward/direct_dial_accept", conference_call_params)
    post :direct_dial_accept, conference_call_params
    @freshfone_call.reload
    expect(xml).to be_truthy
    expect(xml).to have_key(:Response)
    Twilio::REST::Calls.any_instance.unstub(:get)
  end

  it 'should connect the direct dial and give out the connect twiml verb accordingly' do
    create_freshfone_call
    params = { :CallSid => @freshfone_call.call_sid }
    set_twilio_signature("freshfone/forward/direct_dial_connect", params)
    post :direct_dial_connect, params
    expect(xml).to be_truthy
    expect(xml).to have_key(:Response)
    expect(xml[:Response]).to have_key(:Dial)
    expect(xml[:Response][:Dial]).to have_key(:Conference)
  end

  it 'should have dial call status as no-answer when answered by machine' do
    create_freshfone_call
    params = conference_call_params.merge!({ :AnsweredBy => 'machine' })
    set_twilio_signature('freshfone/forward/direct_dial_complete', params)
    post :direct_dial_complete, params
    @freshfone_call.reload
    expect(xml).to be_truthy
    expect(xml.key?(:Response)).to be true
    expect(@freshfone_call.call_status).to eq(Freshfone::Call::CALL_STATUS_HASH[:'no-answer'])
  end

  it 'should have dial call status as no-answer when the intended agent is busy' do
    create_freshfone_call
    stub_twilio_call(:get, [:update])
    (@account.freshfone_subaccount.calls.get).stubs(:status).returns('in-progress')
    params = conference_call_params.merge!({ :CallStatus => 'busy' })
    set_twilio_signature('freshfone/forward/direct_dial_complete', params)
    post :direct_dial_complete, params
    @freshfone_call.reload
    expect(xml).to be_truthy
    expect(xml.key?(:Response)).to be true
    expect(@freshfone_call.call_status).to eq(Freshfone::Call::CALL_STATUS_HASH[:'no-answer'])
    Twilio::REST::Calls.any_instance.unstub(:get)
  end

  it 'should have dial call status as no-answer when the intended agent answered the call' do
    create_freshfone_call
    params = conference_call_params.merge!({ :CallStatus => 'answered' })
    set_twilio_signature('freshfone/forward/direct_dial_complete', params)
    post :direct_dial_complete, params
    @freshfone_call.reload
    expect(xml).to be_truthy
    expect(xml.key?(:Response)).to be true
    expect(@freshfone_call.call_status).to eq(Freshfone::Call::CALL_STATUS_HASH[:completed])
  end

  it 'should have dial call status as no-answer when the intended agent couldn`t be reached' do
    create_freshfone_call
    params = conference_call_params.merge!({ :CallStatus => 'canceled' })
    set_twilio_signature('freshfone/forward/direct_dial_complete', params)
    post :direct_dial_complete, params
    @freshfone_call.reload
    expect(xml).to be_truthy
    expect(xml.key?(:Response)).to be true
    expect(@freshfone_call.call_status).to eq(Freshfone::Call::CALL_STATUS_STR_HASH['no-answer'])
  end

  it 'should return empty twiml on forward to mobile was accepted and the call was completed' do
    create_online_freshfone_user
    create_freshfone_call
    create_call_meta
    create_pinged_agents(true)
    stub_twilio_queues
    twilio_call = stub_twilio_call(:get, [:update])
    twilio_call.expects(:update).never
    set_twilio_signature("freshfone/forward/complete?call=#{@freshfone_call.id}&agent=#{@agent.id}", forward_complete_params)
    post :complete, forward_complete_params.merge({ :agent => @agent.id, :call => @freshfone_call.id })
    expect(xml).to be_truthy
    expect(xml).to have_key(:Response)
    Twilio::REST::Calls.any_instance.unstub(:get)
    Twilio::REST::Queues.any_instance.unstub(:get)
  end

  it 'should notify the source agent on transfer-forward to mobile was rejected' do
    create_online_freshfone_user
    create_call_family
    create_call_meta(@parent_call.children.last)
    create_pinged_agents(false,@parent_call.children.last)
    reqst_params = forward_complete_params.merge({ :agent_id => @agent.id, :call => @parent_call.id, 'AnsweredBy' => 'machine' })
    set_twilio_signature("freshfone/forward/transfer_complete?call=#{@parent_call.id}&agent_id=#{@agent.id}", reqst_params.except(*[:call, :agent_id]))
    post :transfer_complete, reqst_params
    expect(xml).to be_truthy
    expect(xml).to have_key(:Response)
    expect(xml[:Response]).to have_key(:Comment)
    expect(xml[:Response][:Comment]).to match(/Agent #{reqst_params[:agent_id]} ignored the forwarded call/)
    expect(xml[:Response]).to have_key(:Hangup)
  end
end

