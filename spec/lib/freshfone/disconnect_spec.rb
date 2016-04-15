require 'spec_helper'
include Redis::RedisKeys

RSpec.configure do |c|
  c.include Redis::IntegrationsRedis
end

RSpec.describe Freshfone::Disconnect do
  self.use_transactional_fixtures = false
  
  before(:all) do
    @agent = get_admin
    @account.freshfone_numbers.delete_all
  end

  before(:each) do
    create_test_freshfone_account
    @account.freshfone_calls.delete_all
    @account.freshfone_callers.delete_all
    create_freshfone_user
    create_freshfone_call   
    create_call_meta
  end

  it 'should initiate disconnect if leg type is disconnect' do
    create_pinged_agents
    call_leg_params = agent_call_leg_params.merge(:transfer_call => true, :caller_sid => @freshfone_call.id)
    @call_actions = Freshfone::CallActions.new(incoming_params, @account, @number)
    @telephony = Freshfone::Telephony.new(incoming_params, @account, @number)
    Freshfone::Initiator::AgentCallLeg.any_instance.stubs(:current_call).returns(@freshfone_call)
    agent_call_leg = Freshfone::Initiator::AgentCallLeg.new(call_leg_params, @account, @number, @call_actions, @telephony)
    agent_call_leg.process
    @freshfone_user.update_attributes!({:presence => 2, :incoming_preference =>1})
    agent_call_leg.initiate_disconnect.should_not be_falsey
    Freshfone::Initiator::AgentCallLeg.any_instance.unstub(:current_call)
  end

  it 'should perform agent clean up when reset outgoing count is set' do
    create_pinged_agents
    call_leg_params = agent_call_leg_params.merge(:caller_sid => @freshfone_call.id)
    @call_actions = Freshfone::CallActions.new(incoming_params, @account, @number)
    @telephony = Freshfone::Telephony.new(incoming_params, @account, @number)
    Freshfone::Initiator::AgentCallLeg.any_instance.stubs(:reset_outgoing_count).returns(true)
    agent_call_leg = Freshfone::Initiator::AgentCallLeg.new(call_leg_params, @account, @number, @call_actions, @telephony)
    agent_call_leg.process
    agent_call_leg.send(:perform_agent_cleanup).should_not be_falsey
    Freshfone::Initiator::AgentCallLeg.any_instance.unstub(:current_call)
    Freshfone::Initiator::AgentCallLeg.any_instance.unstub(:reset_outgoing_count)
  end

  it 'should not perform agent clean up when reset outgoing count is set' do
    call_leg_params = agent_call_leg_params.merge(:transfer_call => true, :external_number =>"+1234567890", :caller_sid => @freshfone_call.id)
    @call_actions = Freshfone::CallActions.new(incoming_params, @account, @number)
    @telephony = Freshfone::Telephony.new(incoming_params, @account, @number)
    agent_call_leg = Freshfone::Initiator::AgentCallLeg.new(call_leg_params, @account, @number, @call_actions, @telephony)
    agent_call_leg.process
    agent_call_leg.send(:perform_agent_cleanup).should == nil
  end

  it 'should perform call clean up when agent is connected' do
    create_pinged_agents
    @call_actions = Freshfone::CallActions.new(incoming_params, @account, @number)
    @telephony = Freshfone::Telephony.new(incoming_params, @account, @number)
    Freshfone::Initiator::AgentCallLeg.any_instance.stubs(:agent_connected?).returns(true)
    Freshfone::Initiator::AgentCallLeg.any_instance.stubs(:current_call).returns(@freshfone_call)
    agent_call_leg = Freshfone::Initiator::AgentCallLeg.new(agent_call_leg_params, @account, @number, @call_actions, @telephony)
    agent_call_leg.send(:perform_call_cleanup).should_not be_falsey
    Freshfone::Initiator::AgentCallLeg.any_instance.unstub(:current_call)
    Freshfone::Initiator::AgentCallLeg.any_instance.unstub(:agent_connected?)
  end

  it 'should not perform call clean up when agent is not connected' do
    create_pinged_agents
    call_leg_params = agent_call_leg_params.merge(:caller_sid => @freshfone_call.id)
    @call_actions = Freshfone::CallActions.new(incoming_params, @account, @number)
    @telephony = Freshfone::Telephony.new(incoming_params, @account, @number)
    Freshfone::Initiator::AgentCallLeg.any_instance.stubs(:agent_connected?).returns(false)
    agent_call_leg = Freshfone::Initiator::AgentCallLeg.new(call_leg_params, @account, @number, @call_actions, @telephony)
    agent_call_leg.process
    agent_call_leg.send(:perform_call_cleanup).should == nil
    Freshfone::Initiator::AgentCallLeg.any_instance.unstub(:agent_connected?)
  end

  it 'should update the secondary leg if pinged agents contain the current agent' do
    call_leg_params = agent_call_leg_params.merge(:transfer_call => true, :external_number => "+1234567890", :external_transfer => "true", :caller_sid => @freshfone_call.id)
    @call_actions = Freshfone::CallActions.new(call_leg_params, @account, @number)
    @telephony = Freshfone::Telephony.new(incoming_params, @account, @number)
    agent_call_leg = Freshfone::Initiator::AgentCallLeg.new(call_leg_params, @account, @number, @call_actions, @telephony)
    agent_call_leg.process
    agent_call_leg.send(:update_secondary_leg_response).should_not be_falsey
  end

  it 'should not update the secondary leg if pinged agents does not contain the current agent' do
    call_leg_params = agent_call_leg_params.merge(:transfer_call => true, :agent_id => 2, :caller_sid => @freshfone_call.id)
    @call_actions = Freshfone::CallActions.new(call_leg_params, @account, @number)
    @telephony = Freshfone::Telephony.new(incoming_params, @account, @number)
    agent_call_leg = Freshfone::Initiator::AgentCallLeg.new(call_leg_params, @account, @number, @call_actions, @telephony)
    agent_call_leg.process
    agent_call_leg.send(:update_secondary_leg_response).should == nil
  end

  it 'should return missed tranfer agents' do
    call_leg_params = agent_call_leg_params.merge(:transfer_call => true, :caller_sid => @freshfone_call.id)
    @call_actions = Freshfone::CallActions.new(incoming_params, @account, @number)
    @telephony = Freshfone::Telephony.new(incoming_params, @account, @number)
    Freshfone::Initiator::AgentCallLeg.any_instance.stubs(:current_call).returns(@freshfone_call)
    agent_call_leg = Freshfone::Initiator::AgentCallLeg.new(call_leg_params, @account, @number, @call_actions, @telephony)
    agent_call_leg.process
    agent_call_leg.send(:return_missed_transfer).should_not be_falsey
    Freshfone::Initiator::AgentCallLeg.any_instance.unstub(:current_call)
  end

  it 'should initiate voiceamil on disconnect' do
    call_leg_params = agent_call_leg_params.merge(:transfer_call => true, :caller_sid => @freshfone_call.id)
    @call_actions = Freshfone::CallActions.new(incoming_params, @account, @number)
    @telephony = Freshfone::Telephony.new(incoming_params, @account, @number)
    Freshfone::Telephony.any_instance.stubs(:redirect_call).returns(true)
    agent_call_leg = Freshfone::Initiator::AgentCallLeg.new(call_leg_params, @account, @number, @call_actions, @telephony)
    agent_call_leg.process
    agent_call_leg.send(:initiate_voicemail).should_not be_falsey
    Freshfone::Telephony.any_instance.unstub(:redirect_call)
  end

  it 'should handle missed agents' do
    call_leg_params = agent_call_leg_params.merge(:transfer_call => true, :caller_sid => @freshfone_call.id, :round_robin_call => "true")
    @call_actions = Freshfone::CallActions.new(incoming_params, @account, @number)
    @telephony = Freshfone::Telephony.new(incoming_params, @account, @number)
    Freshfone::Telephony.any_instance.stubs(:redirect_call).returns(true)
    agent_call_leg = Freshfone::Initiator::AgentCallLeg.new(call_leg_params, @account, @number, @call_actions, @telephony)
    agent_call_leg.process
    agent_call_leg.send(:handle_round_robin_calls).should_not be_falsey
    Freshfone::Telephony.any_instance.unstub(:redirect_call)
  end

  it 'should return true for a round robin call if round robin call is set' do
    create_pinged_agents
    @freshfone_call_meta.update_attributes!( {:pinged_agents => [{ :response => 1 }] } )
    call_leg_params = agent_call_leg_params.merge(:transfer_call => true, :caller_sid => @freshfone_call.id, :round_robin_call => "true")
    @call_actions = Freshfone::CallActions.new(incoming_params, @account, @number)
    @telephony = Freshfone::Telephony.new(incoming_params, @account, @number)  
    agent_call_leg = Freshfone::Initiator::AgentCallLeg.new(call_leg_params, @account, @number, @call_actions, @telephony)
    agent_call_leg.process
    agent_call_leg.send(:round_robin_call?).should_not be_falsey
  end

  it 'should return false for a round robin call if round robin call is not set' do
    call_leg_params = agent_call_leg_params.merge(:transfer_call => true, :caller_sid => @freshfone_call.id)
    @call_actions = Freshfone::CallActions.new(incoming_params, @account, @number)
    @telephony = Freshfone::Telephony.new(incoming_params, @account, @number)  
    agent_call_leg = Freshfone::Initiator::AgentCallLeg.new(call_leg_params, @account, @number, @call_actions, @telephony)
    agent_call_leg.process
    agent_call_leg.send(:round_robin_call?).should be_falsey
  end

end