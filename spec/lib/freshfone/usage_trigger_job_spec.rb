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

 	it 'should remove second level daily threshold triggers upon security whitelisting' do
		freshfone_account = @account.freshfone_account
		trigger = mock
		trigger.stubs(:delete)
        trigger.stubs(:current_value)
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