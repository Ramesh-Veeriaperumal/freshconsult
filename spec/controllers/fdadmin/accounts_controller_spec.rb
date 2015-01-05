require 'spec_helper'

describe Fdadmin::AccountsController do
	Fdadmin::AccountsController.skip_before_filter :check_freshops_subdomain
	describe "show action for accounts controller " do
		before :each do
			@account = Account.first
			get :show , :account_id => @account.id , :digest => "e361a0c56082d7600c939d4d727580a1dca62039e734bf40f2e6a49e6355b5ab"
		end

		it "must not be routable to the show action without the api key" do
			{ :get => "fdadmin/accounts" }.should be_routable
		end

		it "must have account id existing in the databsae" do
			@account.should_not be_nil
		end

		it "must response success" do
			get :show , :account_id => @account.id , :digest => "e361a0c56082d7600c939d4d727580a1dca62039e734bf40f2e6a49e6355b5ab"
			response.should be_success
		end

		it "must not return an empty hash" do
			account_data = JSON.parse(response.body)
			account_data.should_not be_nil
		end
	end

	describe "add feature action for accounts controller" do

		it "must be routabe to add feature action" do
			{:put=>"fdadmin/accounts/add_feature"}.should be_routable
		end

		it "must throw exception if feature name is not proper" do
			begin
				expect(@account.features?("MULTIPRODUCT")).to raise_error
			rescue
			end
		end

		it "must add a feature if does not exist before" do
			if !@account.features?("multi_product")
				@account.features.send("multi_product").save.should be true
			end
		end

		it "must show notice if the feature is already present" do
			put :add_feature, :account_id => 1 , :feature_name => "multi_product" ,:digest => "5131485a0f3bada04db0931aa8916c6b63d29da94fb01b9263d1dac53a94d3d4"
			result_hash = JSON.parse(response.body).symbolize_keys
			puts "Response Body: #{response.body}"
			result_hash.should include(:status => "notice")
		end
	end

	describe "add day pass action for accounts controller" do


		it "must be routable to the add_day_pass action" do
			{:put=>"fdadmin/accounts/add_day_passes"}.should be_routable
		end

		it "must add passes that are only numeric values" do
			put :add_day_passes , :account_id => 1 , :passes_count => "a"  ,:digest => "c81e4f715b1723948d8d56249015ec3698ea087d8cf6aa91a8b803ab526f16ff"
			result_hash = JSON.parse(response.body).symbolize_keys
			puts "Add day pass(alphabetic)result: #{result_hash}"
			result_hash.should include(:status => "error")
		end

		it "must update day passes maximum of 30" do
			put :add_day_passes, :account_id => 1, :passes_count => 2  ,:digest => "c81e4f715b1723948d8d56249015ec3698ea087d8cf6aa91a8b803ab526f16ff"
			result_hash = JSON.parse(response.body).symbolize_keys
			puts "Add day pass(numeric < 30)result: #{result_hash}"
			result_hash.should include(:status => "success")
		end

		it "must not update day passes greater than 30" do
			put :add_day_passes, :account_id => 1, :passes_count => 40  ,:digest => "c81e4f715b1723948d8d56249015ec3698ea087d8cf6aa91a8b803ab526f16ff"
			result_hash = JSON.parse(response.body).symbolize_keys
			puts "Add day pass(numeric > 30)result: #{result_hash}"
			result_hash.should include(:status => "notice")
		end

	end

	describe "change accounts url action for accounts controller" do
		before :each do
			@account = Account.first
		end
		it "must be routable to change_account_url action" do
			{:put=>"fdadmin/accounts/change_url"}.should be_routable
		end

		it "must check if the new domain is reserved domain" do
			put :change_url, :domain_name => @account.full_domain , :new_url => "blog.freshdesk.com" ,:digest => "d80ede8d270d30e3f05702dd4a43b5811420ce8aaa3d917d63093c79591d6f41"
			result_hash = JSON.parse(response.body).symbolize_keys
			result_hash.should include(:status => "error")
		end

		it "must check if the current domain and new domain" do
			put :change_url, :domain_name => @account.full_domain , :new_url => @account.full_domain,:digest => "d80ede8d270d30e3f05702dd4a43b5811420ce8aaa3d917d63093c79591d6f41"
			result_hash = JSON.parse(response.body).symbolize_keys
			puts "Change url(current url is same as new) result: #{result_hash}"
			result_hash.should include(:status => "notice")
		end

		it "must succeed if the domain is available" do
			put :change_url, :domain_name => @account.full_domain , :new_url => "guruprasad.freshdesk.com" ,:digest => "d80ede8d270d30e3f05702dd4a43b5811420ce8aaa3d917d63093c79591d6f41"
			result_hash = JSON.parse(response.body).symbolize_keys
			puts "Change url result(new url ): #{result_hash}"
			result_hash.should include(:status => "success")
		end


	end

end
