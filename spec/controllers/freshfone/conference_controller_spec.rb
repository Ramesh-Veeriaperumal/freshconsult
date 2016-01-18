require 'spec_helper'

RSpec.configure do |c|
  c.include FreshfoneSpecHelper
end

RSpec.describe Freshfone::ConferenceController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    create_test_freshfone_account
    @request.host = @account.full_domain
    @account.freshfone_callers.delete_all
    @account.freshfone_calls.destroy_all
    create_freshfone_user
    log_in @agent
    create_freshfone_call
  end

  it 'should play music while customer is waiting in conference room' do
    set_twilio_signature("freshfone/conference/wait", conference_call_params)
    create_call_meta
    create_pinged_agents
    post :wait, conference_call_params
    expect(xml).to be_truthy
    expect(xml).to have_key(:Response)
    expect(xml[:Response]).to have_key(:Play)
    expect(xml[:Response][:Play]).to match(/.mp3/)
  end

  it 'should disconnect the call from both customer and agent while waiting' do
    set_twilio_signature("freshfone/conference/wait", conference_call_params)
    Freshfone::Notifier.any_instance.stubs(:notify_pinged_agents).raises(StandardError)
    post :wait, conference_call_params
    expect(xml).to be_truthy
    expect(xml).to have_key(:Response)
    Freshfone::Notifier.any_instance.unstub(:notify_pinged_agents)
  end

  it 'should make incoming agent wait and hear music till he gets connected to caller' do
  	Twilio::REST::Call.any_instance.stubs(:update)
    create_call_meta
    create_pinged_agents
    set_twilio_signature("freshfone/conference/incoming_agent_wait", conference_call_params)
    post :incoming_agent_wait, conference_call_params
    expect(xml).to be_truthy
    expect(xml).to have_key(:Response)
    expect(xml[:Response]).to have_key(:Play)
    expect(xml[:Response][:Play]).to match(/.mp3/)
    Twilio::REST::Call.any_instance.unstub(:update)
  end

  it 'should make incoming agent and disconnect when an exception occurs while incoming wait' do
    Freshfone::Telephony.any_instance.stubs(:redirect_call_to_conference).raises(StandardError)
    set_twilio_signature("freshfone/conference/incoming_agent_wait", conference_call_params)
    post :incoming_agent_wait, conference_call_params
    expect(xml).to be_truthy
    expect(xml).to have_key(:Response)
    Freshfone::Telephony.any_instance.unstub(:redirect_call_to_conference)
  end

  it 'should connect incoming customer if the agent is available' do
    set_twilio_signature("freshfone/conference/connect_incoming_caller", conference_call_params)
    post :connect_incoming_caller, conference_call_params
    expect(xml).to be_truthy
    expect(xml).to have_key(:Response)
    expect(xml[:Response]).to have_key(:Dial)
    expect(xml[:Response][:Dial]).to have_key(:Conference)
  end

  it 'should disconnect the call if an exception occurs while connecting the incoming caller' do
    Freshfone::Telephony.any_instance.stubs(:initiate_customer_conference).raises(StandardError)
    set_twilio_signature("freshfone/conference/connect_incoming_caller", conference_call_params)
    post :connect_incoming_caller, conference_call_params
    expect(xml).to be_truthy
    expect(xml).to have_key(:Response)
    Freshfone::Telephony.any_instance.unstub(:initiate_customer_conference)
  end

  it 'should make the agent wait and hear the music till the caller pickups' do
    twilio_call = mock
    twilio_call.stubs(:sid).returns('DCSid')
    Twilio::REST::Calls.any_instance.stubs(:create).returns(twilio_call)
    set_twilio_signature("freshfone/conference/agent_wait", conference_call_params)
    post :agent_wait, conference_call_params
    expect(xml).to be_truthy
    expect(xml).to have_key(:Response)
    expect(xml[:Response]).to have_key(:Play)
    expect(xml[:Response][:Play]).to match(/.mp3/)
    Twilio::REST::Calls.any_instance.unstub(:create)
  end

  it 'should connect to the customer when he accepted the call from agent' do
    set_twilio_signature("freshfone/conference/outgoing_accepted", conference_call_params)
    post :outgoing_accepted, conference_call_params
    expect(xml).to be_truthy
    expect(xml).to have_key(:Response)
    expect(xml[:Response]).to have_key(:Dial)
    expect(xml[:Response][:Dial]).to have_key(:Conference)
  end

  it 'should disconnect the call if an exception occurs while accepting the outgoing call to customer' do
    Freshfone::Telephony.any_instance.stubs(:initiate_outgoing).raises(StandardError)
    set_twilio_signature("freshfone/conference/agent_wait", conference_call_params)
    post :agent_wait, conference_call_params
    expect(xml).to be_truthy
    expect(xml).to have_key(:Response)
    Freshfone::Telephony.any_instance.unstub(:initiate_outgoing)
  end

  it 'should update ringing_at in call metrics when agent_wait triggred' do
    twilio_call = mock
    twilio_call.stubs(:sid).returns('DCSid')
    Twilio::REST::Calls.any_instance.stubs(:create).returns(twilio_call)
    set_twilio_signature("freshfone/conference/agent_wait", conference_call_params)
    post :agent_wait, conference_call_params
    call_metrics = @freshfone_call.call_metrics.reload
    expect(call_metrics.ringing_at).not_to be_nil
    Twilio::REST::Calls.any_instance.unstub(:create)
  end

  it 'should update answered_at in call metrics when he accepted the call from agent' do
    set_twilio_signature("freshfone/conference/outgoing_accepted", conference_call_params)
    post :outgoing_accepted, conference_call_params
    call_metrics = @freshfone_call.call_metrics.reload
    expect(call_metrics.answered_at).not_to be_nil
  end
end
