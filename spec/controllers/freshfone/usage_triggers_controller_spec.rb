require 'spec_helper'
RSpec.configure do |c|
  c.include UsageTriggersSpecHelper
end

RSpec.describe Freshfone::UsageTriggersController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    Freshfone::Account.delete_all
    Twilio::REST::Triggers.any_instance.stubs(:create)
  end

  before(:each) do
    create_test_freshfone_account
    @request.host = @account.full_domain
  end

  after(:each) do
    # @usage_trigger.destroy
  end

  after(:all) do
  	Twilio::REST::Triggers.any_instance.unstub(:create)
  end

  it 'should notify on trigger alert for credit_overdraft' do
    create_ut :credit_overdraft
    Freshfone::OpsNotifier.any_instance.stubs(:alert)
    set_twilio_signature('freshfone/usage_triggers/notify', credit_overdraft_params)
    post :notify, credit_overdraft_params
    assigns[:trigger].fired_value.should be_eql(50)
  end

  it 'should notify on trigger alert for daily_credit_threshold' do
    create_ut :daily_credit_threshold
    Freshfone::OpsNotifier.any_instance.stubs(:alert)
    set_twilio_signature('freshfone/usage_triggers/notify', daily_credit_threshold_params)
    post :notify, daily_credit_threshold_params
    usage_trigger = Freshfone::UsageTrigger.first(:conditions => {
      :sid => "UTdaily_credit_threshold", 
      :idempotency_token => "AC626dc6e5b03904e6270f353f4a2f068f-FIRES-UTdaily_credit_threshold-2014-04-21"})
    usage_trigger.fired_value.should be_eql(12)
  end

  it 'should not notify on exceptions' do
    create_ut :daily_credit_threshold
    Freshfone::OpsNotifier.any_instance.stubs(:alert_call)
    controller.stubs(:update_trigger).raises(Twilio::REST::RequestError, 'This is an exceptional message')
    set_twilio_signature('freshfone/usage_triggers/notify', daily_credit_threshold_params)
    post :notify, daily_credit_threshold_params
    assigns[:trigger].fired_value.should_not be_eql(50)
  end

  it 'should suspend account for second level of daily_credit_threshold trigger call back' do
  	create_ut :daily_credit_threshold, 200
  	Freshfone::OpsNotifier.any_instance.stubs(:alert_call)
  	Freshfone::OpsNotifier.any_instance.stubs(:alert_mail)

  	set_twilio_signature('freshfone/usage_triggers/notify',
  		daily_credit_threshold_params.merge('TriggerValue' => "#{Freshfone::Account::TRIGGER_LEVELS_HASH[:second_level]}"))
  	post :notify, daily_credit_threshold_params.merge('TriggerValue' => "#{Freshfone::Account::TRIGGER_LEVELS_HASH[:second_level]}")
  	@account.freshfone_account.reload
  	expect(assigns['ops_notifier'].message).to match(/The Trigger Value is #{Freshfone::Account::TRIGGER_LEVELS_HASH[:second_level]}/)
		expect(@account.freshfone_account.suspended?).to be true
		Freshfone::OpsNotifier.any_instance.unstub(:alert_call)
  	Freshfone::OpsNotifier.any_instance.unstub(:alert_mail)
  end

  it 'should accept the call back of first level of daily threshold trigger even the freshfone account is whitelisted' do
  	create_ut :daily_credit_threshold, Freshfone::Account::TRIGGER_LEVELS_HASH[:first_level]
  	@account.freshfone_account.update_column(:security_whitelist, true)
  	Freshfone::OpsNotifier.any_instance.expects(:alert_call).once
  	Freshfone::OpsNotifier.any_instance.stubs(:alert_call)
  	@account.freshfone_account.reload
  	set_twilio_signature('freshfone/usage_triggers/notify',
  		daily_credit_threshold_params.merge('TriggerValue' => "#{Freshfone::Account::TRIGGER_LEVELS_HASH[:first_level]}"))
  	post :notify, daily_credit_threshold_params.merge('TriggerValue' => "#{Freshfone::Account::TRIGGER_LEVELS_HASH[:first_level]}")

  	expect(@account.freshfone_account.security_whitelist).to be true
  	expect(assigns['ops_notifier'].message).to match(/Alert daily_credit_threshold for account/)
  	@account.freshfone_account.update_column(:security_whitelist, false)
  	Freshfone::OpsNotifier.any_instance.unstub(:alert_call)
  end

  it 'should not accept the call back of second level trigger if it is whitelisted' do
  	create_ut :daily_credit_threshold, 200
  	Freshfone::OpsNotifier.any_instance.stubs(:alert_call)
  	Freshfone::OpsNotifier.any_instance.stubs(:alert_mail)
		@account.freshfone_account.update_column(:security_whitelist, true)
		@account.freshfone_account.reload
  	set_twilio_signature('freshfone/usage_triggers/notify',
  		daily_credit_threshold_params.merge('TriggerValue' => "#{Freshfone::Account::TRIGGER_LEVELS_HASH[:second_level]}"))
  	post :notify, daily_credit_threshold_params.merge('TriggerValue' => "#{Freshfone::Account::TRIGGER_LEVELS_HASH[:second_level]}")
  	@account.freshfone_account.reload
  	expect(response.body).to eq(' ')
  	expect(response.code).to eq('200')
  	expect(@account.freshfone_account.suspended?).to be false
  	@account.freshfone_account.update_column(:security_whitelist, false)
  end

end
