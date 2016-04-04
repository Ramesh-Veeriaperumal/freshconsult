require 'spec_helper'
load 'spec/support/usage_triggers_spec_helper.rb'

RSpec.configure do |config|
  config.include UsageTriggersSpecHelper
end

RSpec.describe Freshfone::UsageTrigger do 
  self.use_transactional_fixtures = false

  before(:each) do
    create_test_freshfone_account
    @freshfone_account = @account.freshfone_account
  end

  after(:each) do
    @freshfone_account.freshfone_usage_triggers.delete_all
  end

  it 'should give us new triggers of type daily credit threshold on the update of triggers' do
    @freshfone_account.triggers.each do |_key, value|
      create_ut :daily_credit_threshold, value
    end
    @usage_trigger.update_column(:sid, "UTdaily_credit_threshold2")#updating second trigger sid
    @freshfone_account.update_column(:triggers, { :first_level => 75, :second_level => 300 }.to_yaml)
    @freshfone_account.reload
    new_triggers = Freshfone::UsageTrigger.find_new_triggers(@freshfone_account, @freshfone_account.freshfone_usage_triggers)
    expect(new_triggers.values.first).to eq(300)
  end

  it 'should give update the triggers by adding new triggers and deleting the old triggers' do
    @freshfone_account.triggers.each do |_key, value|
      create_ut :daily_credit_threshold, value
    end
    @usage_trigger.update_column(:sid, "UTdaily_credit_threshold2")#updating second trigger sid
    params = { :first => '75', :second => '300' }
    Resque.inline = true
    Freshfone::Jobs::UsageTrigger.stubs(:delete_usage_trigger)
    Twilio::REST::Triggers.any_instance.stubs(:create).returns(twilio_mock_helper('SidUT','50',"300"))
    Freshfone::UsageTrigger.update_triggers(@freshfone_account, params)
    ut_trigger = @freshfone_account.freshfone_usage_triggers.where({:sid => 'SidUT'}).first
    expect(ut_trigger.sid).to eq('SidUT')
    expect(ut_trigger.trigger_value).to eq(300)
    Resque.inline = false
    Twilio::REST::Triggers.any_instance.unstub(:create)
    Freshfone::Jobs::UsageTrigger.unstub(:delete_usage_trigger)
  end

  it 'should create trial usage triggers when a call`s total duration is updated' do
    @account.freshfone_account.freshfone_usage_triggers.destroy_all
    load_freshfone_trial
    @calls_usage = @account.freshfone_account.subscription.calls_usage[:minutes][:incoming]
    @freshfone_call = @account.freshfone_calls.create(:freshfone_number_id => @number.id,
      :call_type => 1, :agent => @agent, :params => {:CallSid => "CA2db76c748cb6f081853f80dace462a04"})
    Freshfone::Jobs::UsageTrigger.stubs(:delete_usage_trigger)
    twilio_mock_helper('SidUT','05',"#{@calls_usage+10}")
    Resque.inline = true
    @freshfone_call.update_attributes(total_duration: 10)
    expect(Freshfone::UsageTrigger.trial_triggers_present?(@account.freshfone_account)).to be true
    Twilio::REST::Triggers.any_instance.unstub(:create)
    Freshfone::Jobs::UsageTrigger.unstub(:delete_usage_trigger)
    Resque.inline = false
  end
end