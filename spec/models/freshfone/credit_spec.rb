require 'spec_helper'

RSpec.describe Freshfone::Credit do 
  self.use_transactional_fixtures = false
  
  before(:each) do
    create_test_freshfone_account
  end

  it 'should auto recharge freshfone credits' do
    Billing::Subscription.any_instance.stubs(:purchase_freshfone_credits).returns(true)
    @credit.update_attributes(:available_credit => 5, :recharge_quantity => 25)
    @credit.perform_auto_recharge
    @credit.reload
    @credit.available_credit.to_i.should be_eql(30)
  end

  it 'should not auto recharge on failed purchase' do
    Billing::Subscription.any_instance.stubs(:purchase_freshfone_credits).raises(StandardError.new("Auto recharge prevented!"))
    StandardError.any_instance.stubs(:error_code).returns("500. Your auto recharge is prevented")
    
    @credit.update_attributes(:available_credit => 5, :recharge_quantity => 25)
    
    @credit.perform_auto_recharge
    
    @credit.reload
    @credit.available_credit.to_i.should be_eql(5)
    freshfone_payments = @account.freshfone_payments.find(:first, 
      :conditions => {:status_message => "500. Your auto recharge is prevented"},
      :order => "created_at DESC")
    freshfone_payments.should_not be_blank
  end
end