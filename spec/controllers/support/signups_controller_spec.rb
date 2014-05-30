require 'spec_helper'

describe Support::SignupsController do

  it "should be successfully create new user" do
    test_email = Faker::Internet.email
    post 'create', :user => { :email => test_email }
    @account.user_emails.user_for_email(test_email).should be_an_instance_of(User)
  end
end