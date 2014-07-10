require 'spec_helper'
include UsageTriggersSpecHelper

describe Freshfone::UsageTriggersController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    Freshfone::Account.delete_all
  end

  before(:each) do
    @account.update_attributes(:full_domain => "http://play.ngrok.com")
    create_test_freshfone_account
    @request.host = @account.full_domain
  end

  after(:each) do
    # @usage_trigger.destroy
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
    Freshfone::OpsNotifier.any_instance.stubs(:alert)
    controller.stubs(:update_trigger).raises(Twilio::REST::RequestError, 'This is an exceptional message')
    set_twilio_signature('freshfone/usage_triggers/notify', daily_credit_threshold_params)
    post :notify, daily_credit_threshold_params
    assigns[:trigger].fired_value.should_not be_eql(50)
  end
end