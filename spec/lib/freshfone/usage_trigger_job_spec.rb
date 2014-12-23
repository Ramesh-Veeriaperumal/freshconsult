require 'spec_helper'
load 'spec/support/freshfone_spec_helper.rb'
load 'spec/support/usage_triggers_spec_helper.rb'

RSpec.configure do |c|
  c.include FreshfoneSpecHelper
  c.include UsageTriggersSpecHelper
end

RSpec.describe 'UsageTrigger' do
  self.use_transactional_fixtures = false

  before(:all) do
    #@account = create_test_account
    @agent = get_admin
    create_test_freshfone_account
  end

  after(:all) do
    usage_triggers = Freshfone::UsageTrigger.all
    usage_triggers.each do |usage_trigger|
      ut = Freshfone::Jobs::UsageTrigger.get_trigger usage_trigger.sid
      ut.delete
    end
    Freshfone::UsageTrigger.delete_all
  end

  it 'should create a new credit_overdraft trigger with 15% of available credit' do
    Twilio::REST::Trigger.any_instance.stubs(:delete)
    Account.any_instance.stubs(:full_url).returns("http://play.ngrok.com")
    Freshfone::Jobs::UsageTrigger.perform({:trigger_type => "credit_overdraft", :usage_category => "totalprice"})
    credit_overdraft = Account.current.freshfone_account.freshfone_usage_triggers.previous("credit_overdraft").first
    twilio_ut = Freshfone::Jobs::UsageTrigger.get_trigger credit_overdraft.sid
    twilio_ut.should be_present
    twilio_ut.trigger_value.to_i.should be_eql(credit_overdraft.trigger_value.to_i)
  end

  it 'should create a new credit_overdraft trigger with 15% of purchased credit' do
    Twilio::REST::Trigger.any_instance.stubs(:delete)
    Account.any_instance.stubs(:full_url).returns("http://play.ngrok.com")
    Freshfone::Jobs::UsageTrigger.perform({:trigger_type => "credit_overdraft", :purchased_credit => 10, :usage_category => "totalprice"})
    credit_overdraft = Account.current.freshfone_account.freshfone_usage_triggers.previous("credit_overdraft").first
    twilio_ut = Freshfone::Jobs::UsageTrigger.get_trigger credit_overdraft.sid
    twilio_ut.should be_present
    twilio_ut.trigger_value.to_i.should be_eql(credit_overdraft.trigger_value.to_i)
  end

end