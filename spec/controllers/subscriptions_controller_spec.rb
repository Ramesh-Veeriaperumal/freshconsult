require File.expand_path("#{File.dirname(__FILE__)}/../spec_helper")

# Tests may fail if test db is not in sync with Chargebee account.

describe SubscriptionsController do

  before(:all) do
    @account = create_test_account
    @account.make_current
    5.times do |n|
      @agent = add_agent_to_account(@account, {:name => "Test#{n}", :active => 1, 
        :email => "vijayaraj+00#{n}@freshdesk.com", :token => "xtoQaHDQ7TtTLQ3OKt9#{n}", :role => 1})
      @agent.available = 1
      @agent.save!
    end
  end

  describe "plan changes" do
    it "should update plan" do
      @request.host = @account.full_domain
      @request.env["HTTP_ACCEPT"] = "application/json"
      post "plan", :plan_id => 3, :agent_limit => 5, :billing_cycle => 1
      
      plan = SubscriptionPlan.find(3)
      @account.subscription.subscription_plan.should eql plan
      @account.subscription.renewal_period.should eql 1
      @account.subscription.agent_limit.should eql 5
      @account.subscription.free_agents.should eql plan.free_agents
    end

    it "should not update plan if agent_limit < full time agents" do      
      @request.host = @account.full_domain
      @request.env["HTTP_ACCEPT"] = "application/json"
      post "plan", :plan_id => 3, :agent_limit => 2, :billing_cycle => 1
      
      response.body.should eql "Agent Limit exceeded"
    end

    it "should not update plan if unable to collect charges" do
      plan = @account.subscription.subscription_plan
      agent_limit = @account.subscription.agent_limit
      renewal_period = @account.subscription.renewal_period

      @request.host = @account.full_domain
      @request.env["HTTP_ACCEPT"] = "application/json"
      post "plan", :plan_id => 3, :agent_limit => 2, :billing_cycle => 1

      @account.subscription.subscription_plan.should eql plan
      @account.subscription.renewal_period.should eql renewal_period
      @account.subscription.agent_limit.should eql agent_limit
    end
  end


  describe "card updates and activation" do
    it "should update valid card and activate subscription" do
      @request.host = @account.full_domain
      @request.env["HTTP_ACCEPT"] = "application/json"
      post "billing", card_info(:valid, false)

      @account.subscription.card_number.should be_present
      @account.subscription.card_expiration.should be_present
      @account.subscription.state.should eql "active"
    end

    it "should not update invalid card and should not activate" do
      @request.host = @account.full_domain
      @request.env["HTTP_ACCEPT"] = "application/json"
      post "billing", card_info(:invalid, true)

      @account.subscription.card_number.should_not be_present
      @account.subscription.card_expiration.should_not be_present
      @account.subscription.state.should_not eql "active"
    end
  end



end
