require 'spec_helper'
include MailgunHelper

describe MailgunController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  it "should process new mailgun email" do
    email = new_mailgun_email({:email_config => @account.primary_email_config.to_email})
    email.merge!(mailgun_essentials)
    post :create, email
    puts response.status
    response.status.should eql "200 OK"
  end

  it "should give 200 even on wrong address" do
    email = new_mailgun_email({:email_config => Faker::Internet.email})
    email.merge!(mailgun_essentials)
    post :create, email
    puts response.status
    response.status.should eql "200 OK"
  end

  it "should not process as mailgun credentials are missing" do
    email = new_mailgun_email({:email_config => @account.primary_email_config.to_email})
    post :create, email
    puts response.status
    response.status.should eql "302 Found"
  end

end