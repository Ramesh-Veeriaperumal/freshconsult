require 'spec_helper'

describe Admin::Freshfone::CreditsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    create_test_freshfone_account
    @request.host = @account.full_domain
    log_in(@agent)
  end

  it 'redirect to subscription url on successfull credit purchase' do
    @credit.reload
    recharged_credit = @credit.available_credit.to_f + 500
    Billing::Subscription.any_instance.stubs(:purchase_freshfone_credits).returns(true)
    @account.subscription.currency = Subscription::Currency.find_by_name('USD')
    @account.subscription.save
    post :purchase, {:credit => 500}
    Account.first.freshfone_credit.available_credit.to_f.should eql(recharged_credit)
    response.should redirect_to subscription_url
  end

  it 'should enable auto recharge' do
    put :enable_auto_recharge, {:recharge_quantity => 100}
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
    post :purchase, {:credit => 500}
    flash[:error].should be_eql("Error purchasing phone credits.")
  end

  it 'should return error message on invalid recharge amount' do
    post :purchase, {:credit => 2.5}
    flash[:notice].should be_eql("Enter a valid recharge amount")
  end

end