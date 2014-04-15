require 'spec_helper'

describe ContactMergeController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account = create_test_account
    @user = add_test_agent(@account)
    @user1 = add_new_user(@account)
    @user2 = add_new_user(@account)
  end

  before(:each) do
    @request.host = @account.full_domain
    @request.user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36 
                                        (KHTML, like Gecko) Chrome/32.0.1700.107 Safari/537.36"
    log_in(@user)
  end

  it "should pass new contact merge" do
    post :new, :id => @user1.id
    response.body.should =~ /mergebox/
  end

  it "should pass contact merge confirm" do
    post :confirm, :parent_user => @user1.id, :ids => [@user2.id], :id => @user1.id
    response.body.should =~ /Please note that merging will move the entire set of emails, tickets, notes and contact information/
  end

  it "contact_merge complete" do
    post :complete, :parent_user => @user1.id, :target => [@user2.id]
    @account.user_emails.find_all_by_user_id(@user1.id).size.should eql 2
  end

end