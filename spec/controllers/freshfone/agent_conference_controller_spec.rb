require 'spec_helper'
require 'sidekiq/testing'
load 'spec/support/agent_conference_spec_helper.rb'
RSpec.configure do |c|
  c.include AgentConferenceSpecHelper
end

RSpec.describe Freshfone::AgentConferenceController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    enable_agent_conference
  end

  before(:each) do
    create_test_freshfone_account
    create_dummy_freshfone_users(3, Freshfone::User::PRESENCE[:online])
    @request.host = @account.full_domain
    log_in(@dummy_users[0])
  end

  after(:each) do
    @freshfone_call.destroy if @freshfone_call.present?
    @agent_conference_call.destroy if @agent_conference_call.present?
  end

  after(:all) do
    @account.rollback(:agent_conference)
  end

  it 'should render valid json when adding agent to incoming conference call' do
    create_freshfone_call('AGENTCONF', Freshfone::Call::CALL_TYPE_HASH[:incoming],
                           Freshfone::Call::CALL_STATUS_HASH[:'in-progress'])
    request.env['HTTP_ACCEPT'] = 'application/json'
    call = mock
    call.stubs(:sid).returns('AGENTCONFSID')
    call.stubs(:status).returns(Freshfone::SupervisorControl::CALL_STATUS_HASH[:ringing])
    Freshfone::Telephony.any_instance.stubs(:make_call).returns(call)
    Sidekiq::Testing.inline! do
      post :add_agent, add_agent_params(@dummy_users[1].id)
    end
    @freshfone_call.reload
    agent_conf_call = @freshfone_call.supervisor_controls.find_by_supervisor_id(@dummy_users[1].id)
    expect(agent_conf_call.supervisor_control_type).to eql(Freshfone::SupervisorControl::CALL_TYPE_HASH[:agent_conference])
    expect(agent_conf_call.supervisor_control_status).to eql(Freshfone::SupervisorControl::CALL_STATUS_HASH[:ringing])
    expect(json[:status]).to eql('agent_ringing')
    Freshfone::Telephony.unstub(:make_call)
  end

  it 'should render valid json when adding available on agent to incoming conference call' do
    create_freshfone_call('AGENTCONF', Freshfone::Call::CALL_TYPE_HASH[:incoming],
                           Freshfone::Call::CALL_STATUS_HASH[:'in-progress'])
    @dummy_freshfone_users[1].update_attributes!(available_on_phone: true)
    request.env['HTTP_ACCEPT'] = 'application/json'
    call = mock
    call.stubs(:sid).returns('AGENTCONFSID')
    call.stubs(:status).returns(Freshfone::SupervisorControl::CALL_STATUS_HASH[:ringing])
    Freshfone::Telephony.any_instance.stubs(:make_call).returns(call)
    Sidekiq::Testing.inline! do
      post :add_agent, add_agent_params(@dummy_users[1].id)
    end
    @freshfone_call.reload
    agent_conf_call = @freshfone_call.supervisor_controls.find_by_supervisor_id(@dummy_users[1].id)
    expect(agent_conf_call.supervisor_control_type).to eql(Freshfone::SupervisorControl::CALL_TYPE_HASH[:agent_conference])
    expect(agent_conf_call.supervisor_control_status).to eql(Freshfone::SupervisorControl::CALL_STATUS_HASH[:ringing])
    expect(json[:status]).to eql('agent_ringing')
    Freshfone::Telephony.unstub(:make_call)
  end

  it 'should render valid json when adding agent to outgoing conference call' do
    create_freshfone_call('AGENTCONF', Freshfone::Call::CALL_TYPE_HASH[:outgoing],
                           Freshfone::Call::CALL_STATUS_HASH[:'in-progress'])
    request.env['HTTP_ACCEPT'] = 'application/json'
    post :add_agent, add_agent_params(@dummy_users[1].id)
    expect(json[:status]).to eql('agent_ringing')
  end  

  it 'should render valid json when adding agent to onhold conference call' do
    create_freshfone_call('AGENTCONF', Freshfone::Call::CALL_TYPE_HASH[:incoming],
                          Freshfone::Call::CALL_STATUS_HASH[:'on-hold'])
    request.env['HTTP_ACCEPT'] = 'application/json'
    post :add_agent, add_agent_params(@dummy_users[1].id)
    expect(json[:status]).to eql('agent_ringing')
  end

  it 'should render error json when adding agent to completed conference call' do
    create_freshfone_call('AGENTCONF', Freshfone::Call::CALL_TYPE_HASH[:incoming],
                          Freshfone::Call::CALL_STATUS_HASH[:completed])
    request.env['HTTP_ACCEPT'] = 'application/json'
    post :add_agent, add_agent_params(@dummy_users[1].id)
    expect(json).to eql(status: 'error')
  end

  it 'should render error json when adding agent to conference with two agents' do
    create_freshfone_call('AGENTCONF', Freshfone::Call::CALL_TYPE_HASH[:incoming],
                          Freshfone::Call::CALL_STATUS_HASH[:'in-progress'])
    create_agent_conference_call(@dummy_users[2],
                 Freshfone::SupervisorControl::CALL_STATUS_HASH[:'in-progress'])
    request.env['HTTP_ACCEPT'] = 'application/json'
    post :add_agent, add_agent_params(@dummy_users[1].id)
    expect(json).to eql(status: 'error')
  end

  it 'should render valid twiml when second agent is added to conference call' do
    create_freshfone_call('AGENTCONF', Freshfone::Call::CALL_TYPE_HASH[:incoming],
                          Freshfone::Call::CALL_STATUS_HASH[:'in-progress'])
    create_agent_conference_call(@dummy_users[1])
    request.env['HTTP_ACCEPT'] = 'application/json'
    set_twilio_signature("/freshfone/agent_conference/success?call=#{@freshfone_call.id}&add_agent_call_id=#{@agent_conference_call.id}",
            add_agent_success_params.except(*['add_agent_call_id', 'call']))
    post :success, add_agent_success_params.symbolize_keys!
    expect(xml[:Response][:Dial][:Conference]).to match(/Room_1_AGENTCONF/)
  end

  it 'should update user presence to busy when available on phone agent is added to conference call' do
    create_freshfone_call('AGENTCONF', Freshfone::Call::CALL_TYPE_HASH[:incoming],
                          Freshfone::Call::CALL_STATUS_HASH[:'in-progress'])
    create_agent_conference_call(@dummy_users[1])
    @dummy_freshfone_users[1].update_attributes!(available_on_phone: true)
    request.env['HTTP_ACCEPT'] = 'application/json'
    set_twilio_signature("/freshfone/agent_conference/success?call=#{@freshfone_call.id}&add_agent_call_id=#{@agent_conference_call.id}",
            add_agent_success_params.except(*['add_agent_call_id', 'call']))
    post :success, add_agent_success_params.symbolize_keys!
    @dummy_freshfone_users[1].reload
    expect(@dummy_freshfone_users[1].presence).to eql(Freshfone::User::PRESENCE[:busy])
    @dummy_freshfone_users[1].update_attributes!(available_on_phone: false,
                                      presence: Freshfone::User::PRESENCE[:offline])
  end

  it 'should render valid twiml and update duration and call status after conference call' do
    create_freshfone_call('AGENTCONF', Freshfone::Call::CALL_TYPE_HASH[:incoming],
                          Freshfone::Call::CALL_STATUS_HASH[:'in-progress'])
    create_agent_conference_call(@dummy_users[1])
    request.env['HTTP_ACCEPT'] = 'application/json'
    set_twilio_signature("/freshfone/agent_conference/status?call=#{@freshfone_call.id}&add_agent_call_id=#{@agent_conference_call.id}",
       add_agent_status_params.except(*['add_agent_call_id', 'call']))
    post :status, add_agent_status_params.symbolize_keys!
    agent_conf_call = @agent_conference_call.reload
    expect(agent_conf_call.duration).to eql(add_agent_status_params['CallDuration'])
    expected_status = Freshfone::SupervisorControl::CALL_STATUS_HASH[add_agent_status_params['CallStatus'].to_sym]
    expect(agent_conf_call.supervisor_control_status).to eql(expected_status)
    expect(response.body).to match(/Response/)
  end

  it 'should reset user presence when agent conference is ended' do
    create_freshfone_call('AGENTCONF', Freshfone::Call::CALL_TYPE_HASH[:incoming],
                          Freshfone::Call::CALL_STATUS_HASH[:'in-progress'])
    create_agent_conference_call(@dummy_users[1])
    @dummy_freshfone_users[1].update_attributes!(available_on_phone: true)
    request.env['HTTP_ACCEPT'] = 'application/json'
    set_twilio_signature("/freshfone/agent_conference/status?call=#{@freshfone_call.id}&add_agent_call_id=#{@agent_conference_call.id}",
       add_agent_status_params.except(*['add_agent_call_id', 'call']))
    post :status, add_agent_status_params.symbolize_keys!
    @dummy_freshfone_users[1].reload
    expect(@dummy_freshfone_users[1].presence).to eql(@dummy_freshfone_users[1].incoming_preference)
  end

  it 'should render valid json when cancelling agent conference call' do
    create_freshfone_call('AGENTCONF', Freshfone::Call::CALL_TYPE_HASH[:incoming],
                          Freshfone::Call::CALL_STATUS_HASH[:'in-progress'])
    create_agent_conference_call(@dummy_users[1],
                Freshfone::SupervisorControl::CALL_STATUS_HASH[:ringing])
    request.env['HTTP_ACCEPT'] = 'application/json'
    post :cancel, cancel_params
    expect(json[:status]).to eql('agent_conference_canceled')
  end

  it 'should render error when cancelling in-progress agent conference call' do
    create_freshfone_call('AGENTCONF', Freshfone::Call::CALL_TYPE_HASH[:incoming],
                          Freshfone::Call::CALL_STATUS_HASH[:'in-progress'])
    create_agent_conference_call(@dummy_users[1],
                 Freshfone::SupervisorControl::CALL_STATUS_HASH[:'in-progress'])
    request.env['HTTP_ACCEPT'] = 'application/json'
    post :cancel, cancel_params
    expect(json[:status]).to eql('error')
  end
end
