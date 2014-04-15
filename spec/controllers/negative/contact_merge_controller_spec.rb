require 'spec_helper'

describe ContactMergeController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account = create_test_account
    @user = add_test_agent(@account)
    @user1 = add_new_user(@account)
  end

  before(:each) do
    @request.host = @account.full_domain
    @request.user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36
                                        (KHTML, like Gecko) Chrome/32.0.1700.107 Safari/537.36"
    log_in(@user)
  end

  it "should not merge for agent" do
    post :new, :id => @user.id
    puts response.body.inspect
    response.body.should =~ /The change you wanted was rejected/
  end

end
