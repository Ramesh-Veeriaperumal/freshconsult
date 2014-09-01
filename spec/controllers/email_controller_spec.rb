require 'spec_helper'
include EmailHelper

describe EmailController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  it "should process new email" do
    email1 = new_email({:email_config => @account.primary_email_config.to_email})
    post :create, :params => email1
    response.status.should eql "200 OK"
  end

  it "should give new email template" do
    get :new
  end

  it "should give 200 even on wrong address" do
    email2 = new_email({:email_config => Faker::Internet.email})
    post :create, :params => email2
    response.status.should eql "200 OK"
  end

end