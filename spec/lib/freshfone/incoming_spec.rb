require 'spec_helper'
include Redis::RedisKeys

RSpec.configure do |c|
  c.include Redis::IntegrationsRedis
end

RSpec.describe Freshfone::Initiator::Incoming do
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


  it 'should block call' do
    create_freshfone_call     
    create_freshfone_call_meta(@freshfone_call,"+1234567890")
    Freshfone::CallActions.any_instance.stubs(:save_conference_meta).returns(@call_meta)
    incoming=Freshfone::Initiator::Incoming.new(incoming_params, @account, @number)
    incoming.block_call.should_not be_falsey
    Freshfone::CallActions.any_instance.unstub(:save_conference_meta)
  end

  it 'should restrict call' do
    create_freshfone_call     
    create_freshfone_call_meta(@freshfone_call,"+1234567890")
    Freshfone::CallActions.any_instance.stubs(:save_conference_meta).returns(@call_meta)
    incoming=Freshfone::Initiator::Incoming.new(incoming_params, @account, @number)
    incoming.restricted_call.should_not be_falsey
    Freshfone::CallActions.any_instance.unstub(:save_conference_meta)
  end

  it 'should return non availablility' do
    create_freshfone_call     
    create_freshfone_call_meta(@freshfone_call,"+1234567890")
    Freshfone::CallActions.any_instance.stubs(:save_conference_meta).returns(@call_meta)
    incoming=Freshfone::Initiator::Incoming.new(incoming_params.symbolize_keys, @account, @number)
    incoming.return_non_availability.should_not be_falsey
    Freshfone::CallActions.any_instance.unstub(:save_conference_meta)
  end

end
