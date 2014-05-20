require 'spec_helper'

describe Admin::EmailConfigsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    log_in(@user)
  end

  it "should not delete a primary email config" do
    email_config = Factory.build(:primary_email_config, :to_email => Faker::Internet.email, :reply_email => Faker::Internet.email)
    email_config.save
    delete :destroy, { :id => email_config.id }
    @account.all_email_configs.find_by_reply_email(email_config.reply_email).should be_an_instance_of(EmailConfig)
  end
end