require 'spec_helper'
include Redis::RedisKeys

RSpec.configure do |c|
  c.include Redis::IntegrationsRedis
end

RSpec.describe Freshfone::CallCostCalculator do
  self.use_transactional_fixtures = false
  
  before(:all) do
    FRESHFONE_CHARGES = YAML::load_file(File.join(Rails.root, 'config/freshfone', 'freshfone_charges.yml'))
    CALL_DURATION = 120 #by default checking for 2 minutes
  end

  before(:each) do
    create_test_freshfone_account
    create_freshfone_call
    test_call = mock
    test_call.stubs('duration').returns(CALL_DURATION)
    test_call.stubs('price').returns('0.01')
    Twilio::REST::Calls.any_instance.stubs(:get).returns(test_call)
  end

  after(:each) do
    @account.freshfone_calls.delete_all
    @account.freshfone_callers.delete_all
    Twilio::REST::Calls.any_instance.unstub(:get)
  end

  it 'should give call cost for incoming missed call accurately' do
    @freshfone_call.update_column(:call_status, Freshfone::Call::CALL_STATUS_HASH[:'no-answer'])
    args = { :account_id => @account.id, :call => @freshfone_call.id }
    Freshfone::CallCostCalculator.new(args, @account).perform
    @freshfone_call.reload
    expect(@freshfone_call.call_cost).to eq(FRESHFONE_CHARGES['MISSED_OR_BUSY'][:incoming].to_f)
  end

  it 'should give call cost for incoming missed call accurately' do
    @freshfone_call.call_status = Freshfone::Call::CALL_STATUS_HASH[:busy]
    @freshfone_call.call_type = Freshfone::Call::CALL_TYPE_HASH[:outgoing]
    @freshfone_call.sneaky_save
    args = { :account_id => @account.id, :call => @freshfone_call.id }
    Freshfone::CallCostCalculator.new(args, @account).perform
    @freshfone_call.reload
    expect(@freshfone_call.call_cost).to eq(FRESHFONE_CHARGES['MISSED_OR_BUSY'][:outgoing].to_f)
  end

  it 'should give voice mail cost accordingly when it is a standard us number' do
    @freshfone_call.update_column(:call_status, Freshfone::Call::CALL_STATUS_HASH[:voicemail])
    args = { :account_id => @account.id, :call => @freshfone_call.id }
    Freshfone::CallCostCalculator.new(args, @account).perform
    @freshfone_call.reload
    expect(@freshfone_call.call_cost).to eq((CALL_DURATION/60) * FRESHFONE_CHARGES['VOICEMAIL'][:standard])
  end

  it 'should give voice mail cost accordingly when it is a us tollfree number' do
    @freshfone_call.update_column(:call_status, Freshfone::Call::CALL_STATUS_HASH[:voicemail])
    args = { :account_id => @account.id, :call => @freshfone_call.id }
    Freshfone::PulseRate.any_instance.stubs(:toll_free_number?).returns(true)
    Freshfone::CallCostCalculator.new(args, @account).perform
    @freshfone_call.reload
    expect(@freshfone_call.call_cost).to eq((CALL_DURATION/60) * FRESHFONE_CHARGES['VOICEMAIL'][:usca_tollfree])
    Freshfone::PulseRate.any_instance.unstub(:toll_free_number?)
  end

  it 'should give Incoming price accordingly with charge for US Toll Free Number' do
    @freshfone_call.dial_call_sid = 'DDSid'
    @freshfone_call.total_duration = CALL_DURATION
    @freshfone_call.sneaky_save
    Freshfone::PulseRate.any_instance.stubs(:toll_free_number?).returns(true)
    args = { :account_id => @account.id, :call => @freshfone_call.id }
    Freshfone::CallCostCalculator.new(args, @account).perform
    @freshfone_call.reload
    expect(@freshfone_call.call_cost).to eq((CALL_DURATION/60) * FRESHFONE_CHARGES['INCOMING'][:usca_tollfree])
    Freshfone::PulseRate.any_instance.unstub(:toll_free_number?)
  end

  it 'should give Outgoing Price accordingly with charge for US Toll Free Number' do
    completed_outgoing_conference_call
    @freshfone_call.reload
    Freshfone::PulseRate.any_instance.stubs(:toll_free_number?).returns(true)
    args = { :account_id => @account.id, :call => @freshfone_call.id }
    Freshfone::CallCostCalculator.new(args, @account).perform
    @freshfone_call.reload
    expect(@freshfone_call.call_cost).to eq((CALL_DURATION/60) * FRESHFONE_CHARGES['US'][:numbers]['1'][:outgoing])
    Freshfone::PulseRate.any_instance.unstub(:toll_free_number?)
  end

  it 'should try to mail when an exception occurs while billing for a call' do
    Twilio::REST::Calls.any_instance.stubs(:get).raises(StandardError)
    FreshfoneNotifier.any_instance.stubs(:billing_failure)
    FreshfoneNotifier.any_instance.expects(:billing_failure).once
    args = { :account_id => @account.id, :call => @freshfone_call.id }
    Freshfone::CallCostCalculator.new(args, @account).perform
    @freshfone_call.reload
    expect(@freshfone_call.call_cost.blank?).to be true
    FreshfoneNotifier.any_instance.unstub(:billing_failure)
  end

  it 'should update calls beyond threshold count accordingly for calls when it has low credits' do
    @freshfone_call.dial_call_sid = 'DDSid'
    @freshfone_call.total_duration = CALL_DURATION
    @freshfone_call.sneaky_save
    Freshfone::PulseRate.any_instance.stubs(:toll_free_number?).returns(true)
    key = FRESHFONE_CALLS_BEYOND_THRESHOLD % { :account_id => @account.id }
    set_key(key, 52)
    args = { :account_id => @account.id, :call => @freshfone_call.id, :below_safe_threshold => true }
    Freshfone::CallCostCalculator.new(args, @account).perform
    expect(get_key(key).to_i).to eq(36)
    Freshfone::PulseRate.any_instance.unstub(:toll_free_number?)
  end

  it 'should have same cost for calls even the account is not having conference feature enabled' do
    freshfone_call_without_conference
    @freshfone_call.update_column(:call_duration, CALL_DURATION)
    @freshfone_call.reload
    Freshfone::PulseRate.any_instance.stubs(:toll_free_number?).returns(true)
    args = { :account_id => @account.id, :call => @freshfone_call.id }
    Freshfone::CallCostCalculator.new(args, @account).perform
    @freshfone_call.reload
    expect(@freshfone_call.call_cost).to eq((CALL_DURATION/60) * FRESHFONE_CHARGES['INCOMING'][:usca_tollfree])
    Freshfone::PulseRate.any_instance.unstub(:toll_free_number?)
  end

end
