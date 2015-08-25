require 'spec_helper'

describe CustomSurvey::Survey do
	setup :activate_authlogic
    self.use_transactional_fixtures = false
	
	before(:all) do
		@survey = @account.custom_surveys.first
    	@user = User.find_by_account_id(@account.id)
	end

	it "should enable survey settings" do
		@survey.update_attributes(active: true)
		@survey.active == true
	end


	it "should disable survey settings" do
		@survey.update_attributes(active: false)
		@survey.active == false
	end

	it "should create a sample ticket" do
		ticket = CustomSurvey::Survey.sample_ticket(@user);
		ticket.id.should_not eql nil
	end
end