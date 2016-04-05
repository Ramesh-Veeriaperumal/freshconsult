require 'spec_helper'
include Redis::RedisKeys

RSpec.configure do |c|
  c.include Redis::IntegrationsRedis
end

RSpec.describe Freshfone::Initiator::AgentCallLeg do
  self.use_transactional_fixtures = false
  
  before(:all) do
    #@account = create_test_account
    @agent = get_admin
    @account.freshfone_numbers.delete_all
  end

  before(:each) do
    create_test_freshfone_account
    @account.freshfone_calls.delete_all
    @account.freshfone_callers.delete_all
    create_freshfone_user
    create_freshfone_call   
    create_freshfone_call_meta(@freshfone_call,"+1234567890")
    Freshfone::CallActions.any_instance.stubs(:save_conference_meta).returns(@call_meta)
    @call_actions = Freshfone::CallActions.new(incoming_params, @account, @number)
    @telephony = Freshfone::Telephony.new(incoming_params, @account, @number)
  end


  it 'should resolve simulataneous calls with a single or multiple busy agents' do
    call_leg_params = agent_call_leg_params.merge(:CallStatus => "busy",:caller_sid => @freshfone_call.id)
    agent_call_leg = Freshfone::Initiator::AgentCallLeg.new(call_leg_params, @account, @number, @call_actions, @telephony)
    @account.freshfone_users.update_all({presence: Freshfone::User::PRESENCE[:busy], incoming_preference: Freshfone::User::INCOMING[:allowed] })
    @account.freshfone_users.reload
    agent_call_leg.process.should_not be_falsey
    agent_call_leg.send(:all_agents_busy?).should_not be_falsey
    Freshfone::CallActions.any_instance.unstub(:save_conference_meta)
    Freshfone::Initiator::AgentCallLeg.any_instance.unstub(:current_call)
  end

  it 'should not resolve simultaneous calls even if a single agent in available ' do
    call_leg_params = agent_call_leg_params.merge(:CallStatus => "busy",:leg_type => "disconnect", :caller_sid => @freshfone_call.id)
    agent_call_leg = Freshfone::Initiator::AgentCallLeg.new(call_leg_params, @account, @number, @call_actions, @telephony)
    @freshfone_user.update_attributes!({:presence => 1, :incoming_preference =>1})
    agent_call_leg.process.should_not be_falsey
    agent_call_leg.send(:all_agents_busy?).should be_falsey
    agent_call_leg.process.should_not be_falsey
    Freshfone::CallActions.any_instance.unstub(:save_conference_meta)
    Freshfone::Initiator::AgentCallLeg.any_instance.unstub(:current_call)
  end

  it 'should not enqueue a transfered call ' do
    call_leg_params = agent_call_leg_params.merge(:CallStatus => "busy",:leg_type => "disconnect", :transfer_call => true, :caller_sid => @freshfone_call.id)
    agent_call_leg = Freshfone::Initiator::AgentCallLeg.new(call_leg_params, @account, @number, @call_actions, @telephony)
    agent_call_leg.process.should_not be_falsey
    agent_call_leg.send(:all_agents_busy?).should be_falsey
    Freshfone::CallActions.any_instance.unstub(:save_conference_meta)
    Freshfone::Initiator::AgentCallLeg.any_instance.unstub(:current_call)
  end

  it 'should not enqueue a call without a busy call status ' do
    call_leg_params = agent_call_leg_params.merge(:CallStatus => "completed",:leg_type => "disconnect", :caller_sid => @freshfone_call.id)
    agent_call_leg = Freshfone::Initiator::AgentCallLeg.new(call_leg_params, @account, @number, @call_actions, @telephony)
    agent_call_leg.process.should_not be_falsey                 
    agent_call_leg.send(:all_agents_busy?).should be_falsey
    Freshfone::CallActions.any_instance.unstub(:save_conference_meta)
    Freshfone::Initiator::AgentCallLeg.any_instance.unstub(:current_call)
  end

end