require File.expand_path("#{File.dirname(__FILE__)}/../../spec_helper")

# Tests may fail if test db is not in sync with Chargebee account.

describe Billing::BillingController do
	before(:all) do
		@account = create_test_account
    @account.make_current
  end


  it "should update subscription and adds(/removes) a feature as addon" do
  	@request.host = @account.full_domain
    @request.env["HTTP_ACCEPT"] = "application/json"
    
    billing_result = build_test_billing_result
    controller.instance_variable_set(:@billing_data, billing_result) 
    post "trigger", event_params("subscription_changed")

    plan = retrieve_plan(billing_result.subscription.plan_id)
    renewal_period = Billing::Subscription.billing_cycle[billing_result.subscription.plan_id]

    @account.subscription.state.should eql billing_result.subscription.status
    @account.subscription.agent_limit.should eql billing_result.subscription.plan_quantity
    @account.subscription.subscription_plan.should eql plan
    @account.subscription.free_agents.should eql plan.free_agents
    @account.subscription.renewal_period.should eql renewal_period
    
    billing_result.subscription.addons.each do |addon|
      addon_obj = Subscription::Addon.fetch_addon(addon.id)
      @account.addons.should include(addon_obj)
      @account.features?(addon.id.to_sym).should be_true
    end
  end

  it "should not add agent collision to Estate" do
  	@request.host = @account.full_domain
    @request.env["HTTP_ACCEPT"] = "application/json"
    
    billing_result = build_test_billing_result
    controller.instance_variable_set(:@billing_data, billing_result) 
    post "trigger", event_params("subscription_changed")

  	@account.subscription.state.should eql "active"
  	@account.subscription.agent_limit.should eql billing_result.subscription.plan_quantity
  	@account.subscription.subscription_plan.should eql plan
  	@account.subscription.free_agents.should eql plan.free_agents
  	puts @account.features
  	@account.addons.should_not include(Subscription::Addon.find_by_name("Agent Collision"))
  	@account.features?(:agent_collision).should be_true
	end

	it "should update card" do
		@request.host = @account.full_domain
    @request.env["HTTP_ACCEPT"] = "application/json"
    
    billing_result = build_test_billing_result
    controller.instance_variable_set(:@billing_data, billing_result) 
    post "trigger", event_params("card_added")
    
  	card = billing_result.card  	
  	@account.subscription.card_number.should eql card.masked_number 
  	@account.subscription.card_expiration.should eql "%02d-%d" % [card.expiry_month, card.expiry_year]
	end

  it "should suspend subscription" do
    @request.host = @account.full_domain
    @request.env["HTTP_ACCEPT"] = "application/json"
    
    billing_result = build_test_billing_result
    controller.instance_variable_set(:@billing_data, billing_result) 
    post "trigger", event_params("subscription_cancelled")

    @account.subscription.state.should eql "suspended"
  end

  it "should activate subscription" do
    @request.host = @account.full_domain
    @request.env["HTTP_ACCEPT"] = "application/json"
    
    billing_result = build_test_billing_result
    controller.instance_variable_set(:@billing_data, billing_result) 
    post "trigger", event_params("subscription_activated")

    @account.subscription.state.should eql "active"
  end
end