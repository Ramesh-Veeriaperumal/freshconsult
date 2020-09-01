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
			account_data = JSON.parree(response.body)
			account_data.should_not be_nil
		end
	end


	describe "add feature action for accounts controller" do
		Fdadmin::AccountsController.skip_before_filter :verify_signature
		Fdadmin::AccountsController.skip_before_filter :permit_internal_tools_ip
		include Fdadmin::FeatureMethods

		FEATURE_NAMES_BY_TYPE = {
			:bitmap => [:gamification, :requester_widget, :split_tickets, :shared_ownership],
			:db => [:gamification],
			:launchparty => [:requester_widget]
		}

		before(:all) do 
			$redis_routes.perform_redis_op("sadd", Redis::RedisKeys::INTERNAL_TOOLS_IP, "127.0.0.1")
			@account = Account.first
			FEATURE_NAMES_BY_TYPE.each do |feature_type, feature_names|
				feature_names.each do |feature_name|
					send("disable_#{feature_type}_feature", feature_name)
				end
			end
			@account.instance_variable_set("@all_features", nil)
		end

		it "must throw an error for invalid feature name while enabling feature" do
			put :add_feature, :account_id => @account.id , :feature_name => "something", :name_prefix => "fdadmin_", :path_prefix => nil, :format => "json"
			result_hash = JSON.parse(response.body).symbolize_keys
			result_hash.should include(:status => "error")
		end

		it "must throw an error for invalid feature name while disabling feature" do
			put :remove_feature, :account_id => @account.id , :feature_name => "something", :name_prefix => "fdadmin_", :path_prefix => nil, :format => "json"
			result_hash = JSON.parse(response.body).symbolize_keys
			result_hash.should include(:status => "error")
		end

		FEATURE_NAMES_BY_TYPE.keys.each_with_index do |feature_type, i|
			other_types = FEATURE_NAMES_BY_TYPE.keys - [feature_type]
			feature_name = (FEATURE_NAMES_BY_TYPE[feature_type] - FEATURE_NAMES_BY_TYPE.slice(*other_types).values.flatten).first
			feature_name = feature_name.to_sym

			p "****** #{feature_type.upcase} : #{feature_name} ******"
			p other_types

			it "must enable valid #{feature_type} feature that falls only under #{feature_type} classification" do 
				other_types.each do |other_feature_type|
					send("#{other_feature_type}_feature?", feature_name).should be false
				end
				send("#{feature_type}_feature?", feature_name).should be true
				send("disable_#{feature_type}_feature", feature_name)
				reload_account
				send("#{feature_type}_feature_enabled?", feature_name).should be false
				put :add_feature, :account_id => @account.id , :feature_name => feature_name.to_s, :name_prefix => "fdadmin_", :path_prefix => nil
				reload_account
				send("#{feature_type}_feature_enabled?", feature_name).should be true
			end

			it "must not enable valid #{feature_type} feature that falls only under #{feature_type} classification if it's already enabled" do 
				reload_account
				send("#{feature_type}_feature_enabled?", feature_name).should be true
				put :add_feature, :account_id => @account.id , :feature_name => feature_name.to_s, :name_prefix => "fdadmin_", :path_prefix => nil
				result_hash = JSON.parse(response.body).symbolize_keys
				puts "Response Body: #{response.body}"
				result_hash.should include(:status => "notice")
			end

			it "must disable valid #{feature_type} feature that falls only under #{feature_type} classification" do 
				other_types.each do |other_feature_type|
					send("#{other_feature_type}_feature?", feature_name).should be false
				end
				send("#{feature_type}_feature?", feature_name).should be true
				send("enable_#{feature_type}_feature", feature_name)
				reload_account
				send("#{feature_type}_feature_enabled?", feature_name).should be true
				put :remove_feature, :account_id => @account.id , :feature_name => feature_name.to_s, :name_prefix => "fdadmin_", :path_prefix => nil
				reload_account
				send("#{feature_type}_feature_enabled?", feature_name).should be false
			end

			it "must not disable valid #{feature_type} feature that falls only under #{feature_type} classification if it's already disabled" do 
				reload_account
				send("#{feature_type}_feature_enabled?", feature_name).should be false
				put :remove_feature, :account_id => @account.id , :feature_name => feature_name.to_s, :name_prefix => "fdadmin_", :path_prefix => nil
				result_hash = JSON.parse(response.body).symbolize_keys
				puts "Response Body: #{response.body}"
				result_hash.should include(:status => "notice")
			end
		end

		FEATURE_NAMES_BY_TYPE.keys.cycle.each_slice(2).take(3).each do |feature_combination|
			other_feature_type = (FEATURE_NAMES_BY_TYPE.keys - feature_combination).first
			common_feature = (FEATURE_NAMES_BY_TYPE[feature_combination.first] & FEATURE_NAMES_BY_TYPE[feature_combination.last]).first
			p "**** FEATURE COMBINATION #{feature_combination} *****"
			p common_feature

			it "it must enable valid #{feature_combination.first} and #{feature_combination.last} feature if it's disabled under atleast one of them" do 
				disabled_feature_type = feature_combination.sample
				enabled_feature_type = (feature_combination - [disabled_feature_type]).first
				feature_combination.each do |feature_type|
					send("#{feature_type}_feature?", common_feature).should be true
				end
				send("disable_#{disabled_feature_type}_feature", common_feature)
				send("enable_#{enabled_feature_type}_feature", common_feature)
				reload_account
				send("#{enabled_feature_type}_feature_enabled?", common_feature).should be true
				send("#{disabled_feature_type}_feature_enabled?", common_feature).should be false
				put :add_feature, :account_id => @account.id , :feature_name => common_feature.to_s, :name_prefix => "fdadmin_", :path_prefix => nil
				reload_account
				feature_combination.each do |feature_type|
					send("#{feature_type}_feature_enabled?", common_feature).should be true
				end
			end

			it "it must enable valid #{feature_combination.first} and #{feature_combination.last} feature if it's disabled under both of them" do 
				feature_combination.each do |feature_type|
					send("#{feature_type}_feature?", common_feature).should be true
					send("disable_#{feature_type}_feature", common_feature)
					reload_account
					send("#{feature_type}_feature_enabled?", common_feature).should be false
				end
				put :add_feature, :account_id => @account.id , :feature_name => common_feature.to_s, :name_prefix => "fdadmin_", :path_prefix => nil
				reload_account
				feature_combination.each do |feature_type|
					send("#{feature_type}_feature_enabled?", common_feature).should be true
				end
			end

			it "it must not enable valid #{feature_combination.first} and #{feature_combination.last} feature if it's already enabled under both of them" do 
				feature_combination.each do |feature_type|
					send("#{feature_type}_feature?", common_feature).should be true
					send("enable_#{feature_type}_feature", common_feature)
					reload_account
					send("#{feature_type}_feature_enabled?", common_feature).should be true
				end
				put :add_feature, :account_id => @account.id , :feature_name => common_feature.to_s, :name_prefix => "fdadmin_", :path_prefix => nil
				result_hash = JSON.parse(response.body).symbolize_keys
				result_hash.should include(:status => "notice")
			end

			it "it must disable valid #{feature_combination.first} and #{feature_combination.last} feature if it's enabled under atleast one of them" do 
				disabled_feature_type = feature_combination.sample
				enabled_feature_type = (feature_combination - [disabled_feature_type]).first
				feature_combination.each do |feature_type|
					send("#{feature_type}_feature?", common_feature).should be true
				end
				send("disable_#{disabled_feature_type}_feature", common_feature)
				send("enable_#{enabled_feature_type}_feature", common_feature)
				reload_account
				send("#{enabled_feature_type}_feature_enabled?", common_feature).should be true
				send("#{disabled_feature_type}_feature_enabled?", common_feature).should be false
				put :remove_feature, :account_id => @account.id , :feature_name => common_feature.to_s, :name_prefix => "fdadmin_", :path_prefix => nil
				reload_account
				feature_combination.each do |feature_type|
					send("#{feature_type}_feature_enabled?", common_feature).should be false
				end
			end

			it "it must disable valid #{feature_combination.first} and #{feature_combination.last} feature if it's enabled under both of them" do 
				feature_combination.each do |feature_type|
					send("#{feature_type}_feature?", common_feature).should be true
					send("enable_#{feature_type}_feature", common_feature)
					reload_account
					send("#{feature_type}_feature_enabled?", common_feature).should be true
				end
				put :remove_feature, :account_id => @account.id , :feature_name => common_feature.to_s, :name_prefix => "fdadmin_", :path_prefix => nil
				reload_account
				feature_combination.each do |feature_type|
					send("#{feature_type}_feature_enabled?", common_feature).should be false
				end
			end

			it "it must not disable valid #{feature_combination.first} and #{feature_combination.last} feature if it's already disabled under both of them" do 
				feature_combination.each do |feature_type|
					send("#{feature_type}_feature?", common_feature).should be true
					send("disable_#{feature_type}_feature", common_feature)
					reload_account
					send("#{feature_type}_feature_enabled?", common_feature).should be false
				end
				put :remove_feature, :account_id => @account.id , :feature_name => common_feature.to_s, :name_prefix => "fdadmin_", :path_prefix => nil
				result_hash = JSON.parse(response.body).symbolize_keys
				result_hash.should include(:status => "notice")
			end
		end

		def reload_account
			@account.reload
			@account.instance_variable_set("@all_features", nil)
		end

		def db_feature?(feature_name)
			@account.features.respond_to?(feature_name)
		end

		def bitmap_feature?(feature_name)
			Fdadmin::FeatureMethods::BITMAP_FEATURES.include?(feature_name)
		end

		def launchparty_feature?(feature_name)
			Account::LAUNCHPARTY_FEATURES.keys.include?(feature_name)
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

	describe "make an agent as account admin for accounts controller" do 
		before :each do
			@account = Account.first
		end
		it "must be routable to change_account_url action" do
			{:post=>"fdadmin/accounts/make_account_admin"}.should be_routable
		end
	end
end
