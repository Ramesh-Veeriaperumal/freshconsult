require 'spec_helper'

# Tests may fail if test db is not in sync with Chargebee account.


describe SubscriptionsController do
  self.use_transactional_fixtures = false
  setup :activate_authlogic

  before(:all) do
    if @billing_account.blank?
      Account.reset_current_account
      User.current = nil
      Resque.inline = true
      
      @billing_account = create_test_billing_acccount 
      Resque.inline = false               
    
      @account = Account.find(@billing_account.id)
      @user = @account.account_managers.first
      2.times { add_test_agent(@account) }  
    end
  end

  before(:each) do
    log_in(@user)
  end

  it "should get subscription amount in trial" do
#    @request.env["HTTP_ACCEPT"] = "application/json"
    post "calculate_amount", { :currency => "USD", :plan_id => 1, 
      :agent_limit => 1, :billing_cycle => 3 }
    response.should render_template 'subscriptions/_calculate_amount'
  end

  it "should get subscription plan amount" do
#    @request.env["HTTP_ACCEPT"] = "application/json"
    post "calculate_plan_amount", { :currency => "USD", :plan_id => 1, 
      :agent_limit => 1, :billing_cycle => 3 }
    response.should render_template 'subscriptions/_select_plans'
  end

  it "should switch plan in trial" do
    @request.env["HTTP_ACCEPT"] = "application/json"
    post "plan", :plan_id => 2, :agent_limit => "", :billing_cycle => 1, :currency => "USD", :plan_switch => 1

    plan = SubscriptionPlan.find(2)
    @account.subscription.reload
    @account.subscription.state.should eql "trial"
    @account.subscription.subscription_plan.should eql plan
    @account.subscription.renewal_period.should eql 1
    @account.subscription.agent_limit.should eql nil
    @account.subscription.free_agents.should eql plan.free_agents
  end
  
  it "should update plan" do
    @request.env["HTTP_ACCEPT"] = "application/json"
    post "plan", :plan_id => 3, :agent_limit => 10, :billing_cycle => 1, :currency => "USD"
    
    plan = SubscriptionPlan.find(3)
    @account.subscription.reload

    @account.subscription.subscription_plan.should eql plan
    @account.subscription.renewal_period.should eql 1
    @account.subscription.agent_limit.should eql 10
    @account.subscription.free_agents.should eql plan.free_agents
  end

  it "should not update plan if agent_limit < full time agents" do      
    @request.env["HTTP_ACCEPT"] = "application/json"
    post "plan", :plan_id => 3, :agent_limit => 1, :billing_cycle => 1, :currency => "USD"
    
    @account.subscription.agent_limit.should_not eql 2
  end

  it "should switch currency to EUR" do    
    @request.env["HTTP_ACCEPT"] = "application/json"
    post "plan", :plan_id => 3, :agent_limit => 5, :billing_cycle => 1, :currency => "EUR"

    plan = SubscriptionPlan.find(3)
    currency = Subscription::Currency.find_by_name("EUR")
    @account.subscription.reload

    @account.subscription.subscription_plan.should eql plan
    @account.subscription.renewal_period.should eql 1
    @account.subscription.agent_limit.should eql 5
    @account.subscription.currency.should eql currency
  end

  it "should update free plan" do
    @request.env["HTTP_ACCEPT"] = "application/json"
    post "plan", :plan_id => 1, :agent_limit => 3, :billing_cycle => 1, :currency => "USD"

    plan = SubscriptionPlan.find(1)
    currency = Subscription::Currency.find_by_name("USD")
    @account.subscription.reload

    @account.subscription.state.should eql "free"
    @account.subscription.subscription_plan.should eql plan
    @account.subscription.renewal_period.should eql 1
    @account.subscription.agent_limit.should eql 3
    @account.subscription.currency.should eql currency
  end

  it "should not update invalid card and should not activate" do
    @request.env["HTTP_ACCEPT"] = "application/json"
    post "billing", card_info(:invalid, true)

    @account.subscription.reload
    @account.subscription.card_number.should_not be_present
    @account.subscription.card_expiration.should_not be_present
    @account.subscription.state.should_not eql "active"
  end

  it "should update valid card and activate subscription" do      
    @request.env["HTTP_ACCEPT"] = "application/json" 
    post "billing", card_info(:valid, false)
    
    @account.subscription.reload
    @account.subscription.card_number.should be_present
    @account.subscription.card_expiration.should be_present
    @account.subscription.state.should eql "active"
  end

  it "should get subscription amount when active" do
#    @request.env["HTTP_ACCEPT"] = "application/json"
    post "calculate_amount", { :currency => "USD", :plan_id => 1, 
      :agent_limit => 1, :billing_cycle => 3 }

    response.should render_template 'subscriptions/_calculate_amount'
  end


end
