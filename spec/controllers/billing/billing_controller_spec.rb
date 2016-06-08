require 'spec_helper'

# Tests may fail if test db is not in sync with Chargebee account.

describe Billing::BillingController do
  self.use_transactional_fixtures = false

  before(:all) do
    if @billing_account.blank?
      Account.reset_current_account
      User.current = nil
      
      Resque.inline = true
      @billing_account = create_test_billing_acccount
      Resque.inline = false               
      @billing_account.reload      
      @account = Account.find(@billing_account.id)      
    end
  end

  before(:each) do
    @account.make_current
    @request.host = "billing.freshpo.com"
    @request.env["HTTP_ACCEPT"] = "application/json"
    @request.env["HTTP_AUTHORIZATION"] = "Basic " + Base64::encode64("freshdesk:FDCB$6MUSD") 
  end

  it "should update subscription and adds(/removes) a feature as addon" do  
    billing_result = build_test_billing_result(@account.id)
    @account.subscription.addons = [ Subscription::Addon.first ]
    @account.subscription.agent_limit = 1
    
    Billing::Subscription.new.update_subscription(@account.subscription, true, @account.subscription.addons)
    
    post "trigger", event_params(@account.id, "subscription_changed")

    plan = retrieve_plan(billing_result.subscription.plan_id)
    renewal_period = Billing::Subscription.billing_cycle[billing_result.subscription.plan_id]
    
    @account = Account.find_by_id(billing_result.subscription.id)
    @account.subscription.agent_limit.should eql billing_result.subscription.plan_quantity
    @account.subscription.subscription_plan.should eql plan
    @account.subscription.free_agents.should eql plan.free_agents
    @account.subscription.renewal_period.should eql renewal_period
    
    billing_result.subscription.addons.each do |addon|
      addon_obj = Subscription::Addon.fetch_addon(addon.id)
      @account.addons.should include(addon_obj)
      @account.features?(addon.id.to_sym).should be_truthy
    end
  end

	it "should activate free subscription" do
    @account.subscription.addons = []    
    Billing::Subscription.new.update_subscription(@account.subscription, true, @account.subscription.addons)

    plan = SubscriptionPlan.find_by_name("Sprout")
    @account.subscription.subscription_plan = plan
    @account.subscription.convert_to_free
    address = {
      :billing_address => 
      {
        :first_name => "Hi",
        :last_name => "Hello",
        :line1 => "Hello World", 
        :city => "Chennai", 
        :state => "TN",
        :zip => "121212", 
        :country => "India"
      }
    }
    Billing::Subscription.new.activate_subscription(@account.subscription, address)
    @account.subscription.save!
    @account.subscription.reload
  
    billing_result = build_test_billing_result(@account.id)
    post "trigger", event_params(@account.id, "subscription_activated")
    
  	@account.subscription.agent_limit.should eql 3
    @account.subscription.subscription_plan.should eql plan
    @account.subscription.free_agents.should eql plan.free_agents
	end

  it "should suspend subscription" do    
    Billing::Subscription.new.cancel_subscription(@account)    
    post "trigger", event_params(@account.id, "subscription_cancelled")

    @account.subscription.reload
    @account.subscription.state.should eql "suspended"
  end

  it "should reactivate subscription" do
    Billing::Subscription.new.reactivate_subscription(@account.subscription) 
    billing_result = build_test_billing_result(@account.id)    
    post "trigger", event_params(@account.id, "subscription_reactivated")

    @account.subscription.reload
    @account.subscription.state.should_not eql "suspended"
  end

  it "should add payment record" do
    Billing::Subscription.new
    result = ChargeBee::Event.retrieve("ev_HvQquDQOfHPR48J6K")
    transaction_id = result.event.content.transaction.id_at_gateway
    post "trigger", result.as_json["response"][:event]

    SubscriptionPayment.find_by_transaction_id(transaction_id).should be_present
  end
end