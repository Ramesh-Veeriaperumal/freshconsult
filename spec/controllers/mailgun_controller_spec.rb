require 'spec_helper'

RSpec.configure do |c|
  c.include MailgunHelper
end

RSpec.describe MailgunController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  it "should process new mailgun email" do
    email = new_mailgun_email({:email_config => @account.primary_email_config.to_email})
    email.merge!(mailgun_essentials)
    post :create, email
    response.status.should eql 200
  end

  it "should give 200 even on wrong address" do
    email = new_mailgun_email({:email_config => Faker::Internet.email})
    email.merge!(mailgun_essentials)
    post :create, email
    response.status.should eql 200
  end

  it "should not process as mailgun credentials are missing" do
    email = new_mailgun_email({:email_config => @account.primary_email_config.to_email})
    post :create, email
    response.status.should eql 302
  end

end