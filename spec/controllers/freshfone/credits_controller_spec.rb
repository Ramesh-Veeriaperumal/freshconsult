require 'spec_helper'

describe Admin::Freshfone::CreditsController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    create_test_freshfone_account
    @request.host = @account.full_domain
    log_in(@agent)
  end

  it 'redirect to subscription url on successfull credit purchase' do
    recharged_credit = @credit.available_credit.to_f + 500
    Billing::Subscription.any_instance.stubs(:purchase_freshfone_credits).returns(true)
    post :purchase, {:freshfone_credits => {:credit => 500}}
    Account.first.freshfone_credit.available_credit.to_f.should be_eql(recharged_credit)
    response.should redirect_to subscription_url
  end

  it 'should enable auto recharge' do
    put :enable_auto_recharge, {:freshfone_credits => {:recharge_quantity => 100}}
    Account.first.freshfone_credit.recharge_quantity.should be_eql(100)
    response.should redirect_to subscription_url
  end

  it 'should disable auto recharge' do
    put :disable_auto_recharge
    Account.first.freshfone_credit.recharge_quantity.should be_nil
    response.should redirect_to subscription_url
  end

  it 'should return error message on failed purchase' do
    Freshfone::Credit.any_instance.stubs(:purchase).returns(false)
    post :purchase, {:freshfone_credits => {:credit => 500}}
    flash[:error].should be_eql("Error purchasing Freshfone Credits")
  end

  it 'should return error message on invalid recharge amount' do
    post :purchase, {:freshfone_credits => {:credit => 2.5}}
    flash[:notice].should be_eql("Enter a valid recharge amount")
  end

end