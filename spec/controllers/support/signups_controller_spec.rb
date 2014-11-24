require 'spec_helper'

describe Support::SignupsController do
    setup :activate_authlogic
    self.use_transactional_fixtures = false

  before(:all) do
    @account.features.send(:signup_link).create
  end

  it "should display new signup page" do
    get :new
    response.should render_template 'support/signups/new'
    response.should be_success
  end

  it "should not display new signup page when user logged_in" do
    user = add_test_agent(@account)
    log_in(user)
    get :new
    response.location.should =~ /login/
    response.should_not be_success
  end

  it "should be successfully create new user" do
    test_email = Faker::Internet.email
    post 'create', :user => { :email => test_email }
    session[:flash][:notice].should eql "Activation link has been sent to #{test_email}"
    @account.user_emails.user_for_email(test_email).should be_an_instance_of(User)
  end

  it "should be successfully create new user without activation email" do
    notification = @account.email_notifications.find_by_notification_type(EmailNotification::USER_ACTIVATION)
    notification.requester_notification = false
    notification.save(:validate => false)
    test_email = Faker::Internet.email
    post 'create', :user => { :email => test_email }
    session[:flash][:notice].should eql "Successfully registered"
    @account.user_emails.user_for_email(test_email).should be_an_instance_of(User)
  end

  it "should not create a new user without a email" do
    post :create, :user => { :email => "" }
    response.should render_template 'support/signups/new'
  end

  it "should not create a new user with an invalid email" do
    post :create, :user => { :email => Faker::Lorem.sentence }
    response.should render_template 'support/signups/new'
  end
end