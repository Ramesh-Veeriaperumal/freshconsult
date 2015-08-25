require 'spec_helper'
load 'spec/support/usage_triggers_spec_helper.rb'
load 'spec/support/freshfone_actions_spec_helper.rb'

RSpec.configure do |c|
  c.include UsageTriggersSpecHelper
  c.include FreshfoneActionsSpecHelper
end

RSpec.describe 'UsageTrigger' do
  self.use_transactional_fixtures = false

  before(:all) do
    #@account = create_test_account
    @agent = get_admin
    create_test_freshfone_account
  end

  after(:each) do
    Freshfone::UsageTrigger.delete_all
  end

  it 'should create a new credit_overdraft trigger with 15% of available credit' do
    Twilio::REST::Trigger.any_instance.stubs(:delete)
    Account.any_instance.stubs(:full_url).returns("http://play.ngrok.com")
    trigger = mock
    trigger.stubs(:sid).returns('UTSid')
    trigger.stubs(:current_value).returns("#{@account.freshfone_credit.available_credit}")
    trigger.stubs(:trigger_value).returns('100')
    trigger.stubs(:present?).returns(true)
    Twilio::REST::Triggers.any_instance.stubs(:create).returns(trigger)
    Twilio::REST::Triggers.any_instance.stubs(:get).returns(trigger)
    Freshfone::Jobs::UsageTrigger.perform({:trigger_type => "credit_overdraft", :usage_category => "totalprice"})
    twilio_ut = Freshfone::Jobs::UsageTrigger.get_trigger trigger.sid
    twilio_ut.should be_present
    twilio_ut.trigger_value.to_i.should be_eql(trigger.trigger_value.to_i)
    Twilio::REST::Trigger.any_instance.unstub(:delete)
    Account.any_instance.unstub(:full_url)
    Twilio::REST::Triggers.any_instance.unstub(:create)
    Twilio::REST::Triggers.any_instance.unstub(:get)
    Twilio::REST::Trigger.any_instance.unstub(:delete)
  end

  it 'should create a new credit_overdraft trigger with 15% of purchased credit' do
    Twilio::REST::Trigger.any_instance.stubs(:delete)
    Account.any_instance.stubs(:full_url).returns("http://play.ngrok.com")
    trigger = mock
    Twilio::REST::Triggers.any_instance.stubs(:create).returns(trigger)
    Twilio::REST::Triggers.any_instance.stubs(:get).returns(trigger)
    trigger.stubs(:sid).returns('TRIGR')
    trigger.stubs(:trigger_value).returns("100")
    trigger.stubs(:present?).returns(true)
    trigger.stubs(:current_value).returns('10')
    Freshfone::Jobs::UsageTrigger.perform({:trigger_type => "credit_overdraft", :purchased_credit => 10, :usage_category => "totalprice"})
    credit_overdraft = Account.current.freshfone_account.freshfone_usage_triggers.previous("credit_overdraft").first
    twilio_ut = Freshfone::Jobs::UsageTrigger.get_trigger credit_overdraft.sid
    twilio_ut.should be_present
    twilio_ut.trigger_value.to_i.should be_eql(credit_overdraft.trigger_value.to_i)
    Twilio::REST::Trigger.any_instance.unstub(:delete)
    Account.any_instance.unstub(:full_url)
    Twilio::REST::Triggers.any_instance.stubs(:create)
    Twilio::REST::Triggers.any_instance.stubs(:get)
  end
 	it 'should remove second level daily threshold triggers upon security whitelisting' do
		freshfone_account = @account.freshfone_account
		trigger = mock
		trigger.stubs(:delete)
		Freshfone::Jobs::UsageTrigger.stubs(:get_trigger).returns(trigger)
		create_test_usage_triggers
		freshfone_account.reload
		freshfone_account.freshfone_usage_triggers.reload
		expect(freshfone_account.freshfone_usage_triggers.count).to eq(2)
		Resque.inline = true
		freshfone_account.do_security_whitelist
		Resque.inline = false
		freshfone_account.freshfone_usage_triggers.reload
		expect(freshfone_account.freshfone_usage_triggers.count).to eq(1)
		Freshfone::Jobs::UsageTrigger.unstub(:get_trigger)
	end

	it 'should create second level daily threshold trigger upon security unwhitelisting' do
		freshfone_account = @account.freshfone_account
		freshfone_account.update_column(:security_whitelist, true)
		expect(freshfone_account.freshfone_usage_triggers.count).to eq(0)
		trigger = mock
		trigger.stubs(:sid).returns('TRIGR')
		trigger.stubs(:current_value).returns('0')
		trigger.stubs(:trigger_value).returns('100')
		Twilio::REST::Triggers.any_instance.stubs(:create).returns(trigger)
		Resque.inline = true
		freshfone_account.undo_security_whitelist
		Resque.inline = false
		freshfone_account.freshfone_usage_triggers.reload
		expect(freshfone_account.freshfone_usage_triggers.count).to eq(1)
		Twilio::REST::Triggers.any_instance.unstub(:create)
	end

end