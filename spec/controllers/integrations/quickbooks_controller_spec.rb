require 'spec_helper'
describe Integrations::QuickbooksController do
	setup :activate_authlogic
	self.use_transactional_fixtures = false

	before(:all) do
	  @user = add_test_agent(@account)
	  @quickbooks_installed_app = FactoryGirl.build(:installed_application,
	  		:application_id => 32,
	  		:account_id => @account.id,
	  		:configs => {
	  			:inputs => {
	  				"oauth_token" => "qyprdknZFN66wdrQX1GkXqrjSNQvhhsVkr3yXHqNUZXQmxGn",
	  				"oauth_token_secret" => "NShGHhhYxAuwFvegUvIxcp8OmD8k7ZcQ1g2EhxCY"
	  			}
	  		}
	  	)
	  @quickbooks_installed_app.save!
  end

  before(:each) do
	  log_in(@user)
	end

	it "should refresh access token for quickbooks" do
		get :refresh_access_token, {:controller => "integrations/quickbooks", :action => "refresh_access_token"}
		response.status.should eql 200
	end
end
