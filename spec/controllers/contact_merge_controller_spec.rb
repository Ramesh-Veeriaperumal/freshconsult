require 'spec_helper'

describe ContactMergeController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @user1 = add_new_user(@account)
    @user2 = add_new_user(@account)
  end

  before(:each) do
    login_admin
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