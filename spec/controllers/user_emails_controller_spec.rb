require 'spec_helper'

describe UserEmailsController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account = create_test_account
    @user = add_test_agent(@account)
    @user2 = add_user_with_multiple_emails(@account, 4)
  end

  before(:each) do
    @request.host = @account.full_domain
    @request.user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36
                                        (KHTML, like Gecko) Chrome/32.0.1700.107 Safari/537.36"
    log_in(@user)
  end

  it "should make email primary" do
    @user2.user_emails.first.update_attributes({:verified => true})
    @user2.user_emails.last.update_attributes({:verified => true})
    last_id = @user2.user_emails.last.id
    get :make_primary, :id => @user2.id, :email_id => last_id
    @user2.user_emails.find(:all, :conditions => {:user_id => @user2.id, :primary_role => true}).first.id.should eql last_id
  end

end