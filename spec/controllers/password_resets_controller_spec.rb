require 'spec_helper'

describe PasswordResetsController do
	setup :activate_authlogic
	self.use_transactional_fixtures = false

	before(:all) do
		test_user = add_test_agent(@account)
		@test_email = test_user.email
	end

	before(:each) do
		Delayed::Job.destroy_all
	end

	it "should render a new PasswordReset form" do
		get :new
		response.body.should =~ /redirected/
	end

	it "should create new password" do
		post :create, :email => @test_email
		session[:flash][:notice].should eql "Instructions to reset your password have been emailed to you. Please check your email."
		response.body.should =~ /redirected/
		Delayed::Job.last.handler.should include("A request to change your password has been made.")
	end

	it "should create new password" do
		post :create, :email => @test_email, :format => 'nmobile'
		response.body.should =~ /Instructions to reset your password have been emailed to you. Please check your email./
		response.should be_success
		Delayed::Job.last.handler.should include("Click here to reset the password.")
	end

	it "should not create new password" do
		post :create, :email => Faker::Internet.email
		session[:flash][:notice].should eql "No user was found with that email address"
    response.location.should =~ /forgot_password/
	end

	it "should not create new password" do
		post :create, :email => Faker::Internet.email, :format => 'nmobile'
		response.body.should =~ /No user was found with that email address/
		response.body.should =~ /failure/
	end

	it "should edit existing password" do
		user = @account.users.find_by_email(@test_email)
		token = user.perishable_token
		get :edit, :id => token
		response.body.should =~ /Change My Password/
		response.should be_success
	end

	it "should not edit existing password" do
		get :edit, :id => "5xkWZy3vNrn5674389tJFm"
		session[:flash][:notice].should eql "We're sorry, but we could not locate your account. If you are having issues try copying and pasting the URL from your email into your browser or restarting the reset password process."
		response.body.should =~ /redirected/
	end

	it "should update existing password" do
		user = @account.users.find_by_email(@test_email)
		token = user.perishable_token
		put :update, :id => token, :user =>{:password =>"[FILTERED]"}
		session[:flash][:notice].should eql "Password successfully updated"
		response.body.should =~ /redirected/
	end
end