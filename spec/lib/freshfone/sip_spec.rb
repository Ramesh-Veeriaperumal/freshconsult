require 'spec_helper'
include Redis::RedisKeys

RSpec.configure do |c|
  c.include Redis::IntegrationsRedis
end

RSpec.describe Freshfone::Initiator::Sip do
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
    @outgoing_key = FRESHFONE_OUTGOING_CALLS_DEVICE % { :account_id => @account.id }
  end

  after(:each) do
    remove_key(@outgoing_key)
  end
  
  it 'should create sip call' do
    remove_key(@outgoing_key)
    add_to_set(@outgoing_key, @agent.id)
    Freshfone::Initiator::Sip.any_instance.stubs(:register_outgoing_device).returns(true)
    sip=Freshfone::Initiator::Sip.new(sip_params, @account, @number)
    result= sip.process   
    expect(result).to match(/Response/)
    expect(result).to match(/Dial/)
    expect(result).to match(/Conference/)
    @account.freshfone_calls.reload
    @account.freshfone_calls.count.should eql 1
    @freshfone_call = @account.freshfone_calls.first
    expect(@freshfone_call.meta.device_type).to eq(Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:sip])
    @freshfone_user.reload
    expect(@freshfone_user.presence).to be Freshfone::User::PRESENCE[:busy]
    expect(remove_value_from_set(@outgoing_key,@agent.id)).to be true
    Freshfone::Initiator::Sip.any_instance.unstub(:register_outgoing_device)
  end

  it 'should not create outgoing call if device already registred' do
    add_to_set(@outgoing_key, @agent.id)
    Freshfone::Initiator::Sip.any_instance.stubs(:register_outgoing_device).returns(false)
    sip=Freshfone::Initiator::Sip.new(sip_params, @account, @number)
    result= sip.process   
    expect(result).to match(/Response/)
    expect(result).to match(/Reject/)
    @account.freshfone_calls.reload
    @account.freshfone_calls.count.should eql 0
    Freshfone::Initiator::Sip.any_instance.unstub(:register_outgoing_device)
  end
end