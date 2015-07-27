require 'spec_helper'

describe Freshfone::Account do 
  self.use_transactional_fixtures = false
  
  before(:each) do
    create_test_freshfone_account
    @freshfone_account = @account.freshfone_account
  end

  it 'should find all accounts that are suspended' do
    expiry_date = Time.zone.now
    @freshfone_account.update_attributes(:expires_on => expiry_date, :state => 2)
    suspended_accounts = Freshfone::Account.find_due(expiry_date)
    suspended_accounts.should be_present
    suspended_accounts.first.friendly_name.should match("RSpec Test")
    @freshfone_account.update_attributes(:expires_on => nil, :state => 1)
  end

end