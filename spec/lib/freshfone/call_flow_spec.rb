require 'spec_helper'
include Redis::RedisKeys

RSpec.configure do |c|
  c.include Redis::IntegrationsRedis
end

RSpec.describe Freshfone::CallFlow do
  self.use_transactional_fixtures = false
  
  before(:all) do
    #@account = create_test_account
    @agent = get_admin
  end

  before(:each) do
    create_test_freshfone_account
    @account.freshfone_calls.delete_all
    @account.freshfone_callers.delete_all
    create_freshfone_user
  end


  it 'should render non availability message if all users in the group are offline' do# failing in master
    group = create_group @account, {:name => "Freshfone Group"}
    call = create_freshfone_call
    @account.freshfone_users.update_all(presence: Freshfone::User::PRESENCE[:offline])
    call_flow = Freshfone::CallFlow.new({:CallSid => call.call_sid}, @account, @number, @agent)
    
    twiml = twimlify call_flow.call_users_in_group(group.id)
    twiml[:Response][:Dial].should be_blank
  end

  it 'should dial online users in a group' do
    group = create_group @account, {:name => "Freshfone Online Group"}
    call = create_freshfone_call
    create_online_freshfone_user
    ag = AgentGroup.new(:user_id => @agent.id, :group_id => group.id)
    ag.account_id = @account.id
    ag.save
    call_flow = Freshfone::CallFlow.new({:CallSid => call.call_sid}, @account, @number, @agent)
    
    twiml = twimlify call_flow.call_users_in_group(group.id)
    twiml[:Response][:Dial].should_not be_blank
    twiml_clients = twiml[:Response][:Dial][:Client]
    # client = twiml_clients.kind_of?(Array) ? twiml_clients.last : twiml_clients
    # client.should be_eql(@agent.id.to_s)
    twiml_clients.should include(@agent.id.to_s)
  end

  it 'should render twiml for regular incoming' do
    create_online_freshfone_user
    call_flow = Freshfone::CallFlow.new({}, @account, @number, @agent)
    twiml = twimlify call_flow.send(:regular_incoming)
    twiml[:Response][:Dial][:Client].should_not be_blank
  end

  it 'should connect call to a specific user given user id' do
    create_online_freshfone_user
    call_flow = Freshfone::CallFlow.new({}, @account, @number, @agent)
    
    twiml = twimlify call_flow.call_user_with_id(@agent.id)
    twiml[:Response][:Dial][:Client].should include(@agent.id.to_s)
  end

  it 'should connect call to a non-busy direct dial number' do
    call = create_freshfone_call
    number = Faker::Base.numerify('(###)###-####')
    call_flow = Freshfone::CallFlow.new({:CallSid => call.call_sid}, @account, @number, @agent)
    
    twiml = twimlify call_flow.call_user_with_number(number)
    twiml[:Response][:Dial][:Number].should be_eql(number)
  end

  it 'should render twiml for an outgoing call' do
  	@number.freshfone_number_groups.delete_all
  	@number.freshfone_number_groups.reload
    number = Faker::Base.numerify('(###)###-####')
    outgoing_key = FRESHFONE_OUTGOING_CALLS_DEVICE % { :account_id => @account.id }
    remove_value_from_set(outgoing_key, @agent.id)
    params = {:CallSid => "CA9cdcef5973752a0895f598a3413a88d5", :PhoneNumber => number, :From => "client:#{@agent.id}"}
    call_flow = Freshfone::CallFlow.new(params, @account, @number, @agent)
    
    twiml = twimlify call_flow.send(:outgoing)
    twiml[:Response][:Dial][:Number].should be_eql(number)
  end

  it 'should return Reject on blocked incoming call' do
    params = {:From => Faker::Base.numerify('(###)###-####')}
    call_flow = Freshfone::CallFlow.new(params, @account, @number, @agent)
    
    twiml = twimlify call_flow.send(:block_call)
    twiml[:Response][:Reject].should_not be_blank
  end

  # it 'should return false on non business hour check before calls' do
  #   call_flow = Freshfone::CallFlow.new({}, @account, @number, @agent)
  #   call_flow.send(:within_business_hours?).should be_falsey
  # end
end