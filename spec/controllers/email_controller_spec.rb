require 'spec_helper'

RSpec.configure do |c|
  c.include EmailHelper
end

RSpec.describe EmailController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  it "should process new email" do
    email1 = new_email({:email_config => RSpec.configuration.account.primary_email_config.to_email})
    post :create, :params => email1
    response.status.should eql 200
  end

  it "should give new email template" do
    get :new
  end

  it "should give 200 even on wrong address" do
    email2 = new_email({:email_config => Faker::Internet.email})
    post :create, :params => email2
    response.status.should eql 200
  end

end