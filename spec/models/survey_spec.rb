require 'spec_helper'
	
describe Survey do
	setup :activate_authlogic
    self.use_transactional_fixtures = false
	
	before(:all) do
		@survey = @account.surveys.first
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
end