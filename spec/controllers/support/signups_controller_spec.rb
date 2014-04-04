require 'spec_helper'

describe Support::SignupsController do

  before do
    @account = create_test_account
    @request.host = @account.full_domain
  end

  it "should be successfully create new user" do
    test_email = Faker::Internet.email
    post 'create', :user => { :email => test_email }
    @account.users.find_by_email(test_email).should be_an_instance_of(User)
  end
end