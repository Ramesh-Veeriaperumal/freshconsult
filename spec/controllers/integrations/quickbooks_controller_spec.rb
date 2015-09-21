require 'spec_helper'
describe Integrations::QuickbooksController do
	setup :activate_authlogic
	self.use_transactional_fixtures = false

	before(:all) do
	  @user = add_test_agent(@account)
	  @quickbooks_installed_app = FactoryGirl.build(:installed_application,
	  		:application_id => Integrations::Application.find_by_name("quickbooks").id,
	  		:account_id => @account.id,
	  		:configs => {
	  			:inputs => {
	  				"oauth_token" => "qyprdtKAuPEa0o9tyzjhtZSxdEuatlH8b01NkaK5iZpjhXOX",
	  				"oauth_token_secret" => "Z6KLRknJLpG1ZZDJJYffFQ1obmFV1Ozr6qUGEMHK"
	  			}
	  		}
	  	)
	  @quickbooks_installed_app.save!
	  @new_user = FactoryGirl.build(:user, :avatar_attributes => { :content => fixture_file_upload('files/image4kb.png', 
                                        'image/png')},
                                    :name => "Test user QuickBooks",
                                    :email => Faker::Internet.email,
                                    :time_zone => "Chennai",
                                    :delta => 1,
                                    :deleted => 0,
                                    :blocked => 0,
                                    :customer_id => nil,
                                    :language => "en")
	  @new_user.save
  end

  before(:each) do
	  log_in(@user)
	end

	it "should refresh access token for quickbooks" do
		get :refresh_access_token, {:controller => "integrations/quickbooks", :action => "refresh_access_token"}
		response.status.should eql 200
	end

	it "should map the user with the given company" do
		post :create_company, {"requester_email" => @new_user[:email], "name" => "Test QuickBooks company"}
		response.status.should eql 200
	end
end
