require 'spec_helper'
include Redis::RedisKeys

RSpec.configure do |c|
  c.include Redis::IntegrationsRedis
end

RSpec.describe Freshfone::Initiator::Outgoing do
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
    remove_value_from_set(@outgoing_key, @agent.id)
  end
  
  it 'should create outgoing call' do
    outgoing=Freshfone::Initiator::Outgoing.new(outgoing_params, @account, @number)
    result= outgoing.process   
    expect(result).to match(/Response/)
    expect(result).to match(/Dial/)
    expect(result).to match(/Conference/)
    @account.freshfone_calls.reload
    @account.freshfone_calls.count.should eql 1
    expect(remove_value_from_set(@outgoing_key,@agent.id)).to be true
  end

  it 'should not create outgoing call if device already registred' do
    add_to_set(@outgoing_key, @agent.id)
    outgoing=Freshfone::Initiator::Outgoing.new(outgoing_params, @account, @number)
    result= outgoing.process   
    expect(result).to match(/Response/)
    expect(result).to match(/Reject/)
    @account.freshfone_calls.reload
    @account.freshfone_calls.count.should eql 0
  end
end