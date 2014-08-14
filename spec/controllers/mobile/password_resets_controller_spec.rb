require 'spec_helper'

describe PasswordResetsController do
    self.use_transactional_fixtures = false

    before(:each) do
    	api_login
  	end

	it "should Reset Password and return an array" do 
		post :create, {
			:email => @agent.email
			}
		json_response.should include("server_response","reset_password")
		json_response["server_response"].should be_eql("Instructions to reset your password have been emailed to you. Please check your email.")
		json_response["reset_password"].should be_eql("success")
	end

	# Negative Cases 

	it "should NOT reset password and return an array for an invalid email" do
		post :create, {
			:email => "invalid_user@notregistered.com"
		}
		json_response.should include("server_response","reset_password")
		json_response["server_response"].should be_eql("No user was found with that email address")
		json_response["reset_password"].should be_eql("failure")
	end
end