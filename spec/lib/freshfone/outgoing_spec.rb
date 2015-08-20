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
  end

  it 'should register outgoing device' do
    @freshfone_call = @account.freshfone_calls.create(  :freshfone_number_id => @number.id, 
                                      :call_status => 0, :call_type => 2, :agent => @agent,
                                      :params => { :CallSid => "CA2db76c748cb6f081853f80dace462a04"})
    @call_meta = @freshfone_call.create_meta(:account_id=> @account.id, :transfer_by_agent => @agent.id,
              :meta_info => "+1234567890", :device_type => Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:external_transfer])
    Freshfone::Initiator::Outgoing.any_instance.stubs(:outbound_call_agent_id).returns(@agent.id)
    outgoing=Freshfone::Initiator::Outgoing.new(incoming_params, @account, @number)
    outgoing.send(:register_outgoing_device).should_not be_falsey
    Freshfone::Initiator::Outgoing.any_instance.unstub(:outbound_call_agent_id)
  end

  it 'should reject outgoing call' do
    @freshfone_call = @account.freshfone_calls.create(  :freshfone_number_id => @number.id, 
                                      :call_status => 0, :call_type => 2, :agent => @agent,
                                      :params => { :CallSid => "CA2db76c748cb6f081853f80dace462a04"})
    @call_meta = @freshfone_call.create_meta(:account_id=> @account.id, :transfer_by_agent => @agent.id,
              :meta_info => "+1234567890", :device_type => Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:external_transfer])
    Freshfone::Initiator::Outgoing.any_instance.stubs(:outbound_call_agent_id).returns(@agent.id)
    outgoing=Freshfone::Initiator::Outgoing.new(incoming_params, @account, @number)
    outgoing.send(:reject_outgoing_call).should_not be_falsey
    Freshfone::Initiator::Outgoing.any_instance.unstub(:outbound_call_agent_id)
  end

  it 'should return outbound call agent id' do
    @freshfone_call = @account.freshfone_calls.create(  :freshfone_number_id => @number.id, 
                                      :call_status => 0, :call_type => 2, :agent => @agent,
                                      :params => { :CallSid => "CA2db76c748cb6f081853f80dace462a04"})
    @call_meta = @freshfone_call.create_meta(:account_id=> @account.id, :transfer_by_agent => @agent.id,
              :meta_info => "+1234567890", :device_type => Freshfone::CallMeta::USER_AGENT_TYPE_HASH[:external_transfer])
    Freshfone::Initiator::Outgoing.any_instance.stubs(:split_client_id).returns(nil)
    outgoing=Freshfone::Initiator::Outgoing.new(incoming_params, @account, @number)
    outgoing.send(:outbound_call_agent_id).should == nil
    Freshfone::Initiator::Outgoing.any_instance.unstub(:split_client_id)
  end

end