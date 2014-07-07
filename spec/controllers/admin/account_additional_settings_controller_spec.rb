require 'spec_helper'

describe Admin::AccountAdditionalSettingsController do
	integrate_views
	setup :activate_authlogic
	self.use_transactional_fixtures = false

	before(:each) do
		login_admin
	end

	it "should display automatic Bcc email form" do
		post :assign_bcc_email
		response.body.should =~ /Bcc address/
		response.should be_success
	end

	it "should update the account_additional_settings" do
		test_email = Faker::Internet.email
		put :update, {
			:account_additional_settings =>{ :bcc_email=> test_email }
		}
		@account.reload
		@account.account_additional_settings.bcc_email.should eql(test_email)
		response.session[:flash][:notice].should eql "Successfully updated Bcc email"
		response.redirected_to.should eql "/admin/email_configs"
	end

	it "should not update the account_additional_settings without emailId" do
		text = Faker::Name.name
		put :update, {
			:account_additional_settings =>{ :bcc_email=> text }
		}
		@account.reload
		@account.account_additional_settings.bcc_email.should_not eql(text)
		response.session[:flash][:notice].should eql "Failed to update Bcc email"
		response.redirected_to.should eql "/admin/email_configs"
	end
end