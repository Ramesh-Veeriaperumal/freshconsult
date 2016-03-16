require 'spec_helper'

RSpec.describe Freshfone::Subscription do 
  self.use_transactional_fixtures = false
  
  before(:each) do
    create_test_freshfone_account
    load_freshfone_trial
    ::Account.current.freshfone_account.reload
  end

  it 'should make the freshfone account status as trial exhaust when both the usage are exceeded' do
    @freshfone_subscription.outbound[:exceeded] = true
    @freshfone_subscription.sneaky_save
    Sidekiq::Testing.inline! do
      @freshfone_subscription.inbound_will_change!
      @freshfone_subscription.inbound_usage_exceeded!
      @account.freshfone_account.reload
      expect(@account.freshfone_account.trial_exhausted?).to be true
    end
  end

  it 'should create trial triggers only when freshfone account is present' do
    @freshfone_subscription.destroy
    Resque.inline = true
    twilio_mock_helper('Sid', 0, '5')
    load_freshfone_trial
    expect(Freshfone::UsageTrigger.trial_triggers_present?(@account.freshfone_account)).to be true
    Twilio::REST::Triggers.any_instance.unstub(:create)
    Resque.inline = false
    @account.freshfone_account.freshfone_usage_triggers.delete_all
  end

end
