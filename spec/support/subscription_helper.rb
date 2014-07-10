#require '../spec_helper'
require File.expand_path("#{File.dirname(__FILE__)}/../spec_helper")

module SubscriptionHelper

	CARD_NUMBERS = { :valid => "4111111111111111", :invalid => "4119862760338320", 
										:no_funds => "4005519200000004"}

	def build_test_billing_result(account_id)
		Billing::Subscription.new.retrieve_subscription(account_id)
	end

	def card_info(validity, expired)
		(card_details(validity, expired)).merge({ :address => address_details })
	end

	def card_details(validity, expired)
		{
			:number => CARD_NUMBERS[validity], 			
      :cvv => "123"
		}.merge!(:creditcard => { :month => "5", :year => (expired ? 2.years.ago.year : 2.years.from_now.year) })
	end

	def address_details
		{
			:address1 =>"SP Infocity", 
			:address2 =>"Perungudi", 
			:city =>"Chennai", 
			:state =>"Tamil Nadu", 
			:country =>"India", 
			:zip => "600096"
		}
	end

	def event_params(id, event)
		{ 
			:content => { :subscription => { :id => id }, :customer => { :id => id }}, 
			:event_type => event, 
			:source => "admin_console", 
			:format => "json" 
		}
	end

	def retrieve_plan(plan_code)
		plan_id = Billing::Subscription.helpkit_plan[plan_code].to_sym
    plan_name = SubscriptionPlan::SUBSCRIPTION_PLANS[plan_id]
    SubscriptionPlan.find_by_name(plan_name)
	end

	def reseller_portal_params
		{
			:timestamp => Time.now.getutc.to_i,
			:user_name => AppConfig["reseller_portal"]["user_name"],
			:password => AppConfig["reseller_portal"]["password"],
			:shared_secret => AppConfig["reseller_portal"]["shared_secret"]
		}
	end

end


