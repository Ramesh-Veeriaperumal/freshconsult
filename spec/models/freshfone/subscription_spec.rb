require 'spec_helper'

RSpec.describe Freshfone::Subscription do 
  self.use_transactional_fixtures = false
  
  before(:each) do
    create_test_freshfone_account
    @account.freshfone_subscription.destroy if @account.freshfone_subscription.present?
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

end
