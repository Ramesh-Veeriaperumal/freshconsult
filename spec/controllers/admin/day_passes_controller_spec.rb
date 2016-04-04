require 'spec_helper'

RSpec.describe Admin::DayPassesController do
	setup :activate_authlogic

  before(:all) do
  	 @account = Account.last

  	 if @account.full_domain.include?("billing")
  	 	# Using the account if created in subscriptions/billing controller.
	   	@account.make_current	  	
	   	@user = @account.account_managers.first	  	
	  else	  	
        Account.reset_current_account
        User.current = nil
      
        Resque.inline = true
        @billing_account = create_test_billing_acccount
        Resque.inline = false               
    
        @account = Account.find(@billing_account.id)
        @user = @account.account_managers.first
	  end
	end

	before(:each) do
    @request.host = @billing_account.full_domain
		log_in(@user)
	end

	it "should list all daypasses" do
		get "index"
		amounts = assigns[:day_pass_amounts]
		amounts.should be_present		
	end

	it "should enable autorecharge and set recharge_quantity" do
		recharge_quantity = 25
		post "update", :day_pass_config => { :auto_recharge => true , :recharge_quantity => recharge_quantity }
		
		day_pass_config = assigns[:day_pass_config]		
		day_pass_config.auto_recharge.should eql true
		day_pass_config.recharge_quantity.should eql recharge_quantity
	end

	it "should not buy daypasses without card info" do	
		purchase_quantity = 10
		put "buy_now", :quantity => purchase_quantity
		
		day_pass_config = assigns[:day_pass_config]
		day_pass_config.available_passes.should be_present
	end

	it "should buy daypasses when subscription is active" do
		billing = Billing::Subscription.new
		address = SubscriptionAddress.new(address_details)
    data = billing_card_details.merge(billing_address(address))
    Billing::ChargebeeWrapper.new.add_card(@account.id, data)
		billing.activate_subscription(@account.subscription, address_details)
		
		purchase_quantity = 10
		put "buy_now", :quantity => purchase_quantity
		
		day_pass_config = assigns[:day_pass_config]
		day_pass_config.available_passes.should be_present
	end
end
