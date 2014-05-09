require 'spec_helper'

describe Admin::EmailConfigsController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account = create_test_account
    @user = add_test_agent(@account)
  end

  before(:each) do
    @request.host = @account.full_domain
    @request.user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36 
                                        (KHTML, like Gecko) Chrome/32.0.1700.107 Safari/537.36"
    log_in(@user)
  end

  it "should not delete a primary email config" do
    email_config = Factory.build(:primary_email_config)
    email_config.save
    delete :destroy, { :id => email_config.id }
    @account.all_email_configs.find_by_reply_email(email_config.reply_email).should be_an_instance_of(EmailConfig)
  end
end