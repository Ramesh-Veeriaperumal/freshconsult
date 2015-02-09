require 'spec_helper'
describe SubscriptionAdmin::FreshfoneActionsController do
	SubscriptionAdmin::FreshfoneActionsController.skip_before_filter :check_admin_subdomain
	SubscriptionAdmin::FreshfoneActionsController.skip_before_filter :check_admin_user_privilege
	SubscriptionAdmin::FreshfoneActionsController.skip_before_filter :notify_freshfone_ops
	
	before :each do
		@account = Account.first
	end

	it "must return the array of country list" do 
		get :get_country_list , :account_id => @account.id
		result = JSON.parse(response.body).symbolize_keys
		result.has_key?(:to_blacklist)
		result.has_key?(:to_whitelist)
	end

	it "should render partial for country_restriction action" do
		xhr :get, :country_restriction, :account_id => @account.id, :country_list => "India", :status => "Whitelist"
	  response.should render_template 'subscription_admin/freshfone_actions/_credits'
  end

	it "must enable country if it is disabled" do 
		xhr :get, :country_restriction, :account_id =>  @account.id,:country_list => "India", :status => "Whitelist"
		if params[:status] == 'Whitelist'
			country_code = Freshfone::Config::WHITELIST_NUMBERS.find{ |key,value| value["name"] == params[:country_list]}.first
			@account.freshfone_whitelist_country.find_by_country(country_code).should_not be_nil
		end
	end

	it "must disable country if it is enabled" do 
		@account.freshfone_whitelist_country.create(:country => "AF")
		xhr :get, :country_restriction, :account_id => @account.id,:country_list => "Afghanistan", :status => "Blacklist"
		if params[:status] == 'Blacklist'
			country_code = Freshfone::Config::WHITELIST_NUMBERS.find{ |key,value| value["name"] == params[:country_list]}.first
			@account.freshfone_whitelist_country.find_by_country(country_code).should be_nil
		end
	end
end
