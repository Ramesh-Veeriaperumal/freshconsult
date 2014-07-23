require 'spec_helper'

describe ContactMergeController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account.features.multiple_user_emails.create
    @user1 = add_user_with_multiple_emails(@account, 2)
    @user2 = add_user_with_multiple_emails(@account, 2)
    Resque.inline = true
  end

  before(:each) do
    login_admin
  end

  after(:all) do
    @account.features.multiple_user_emails.destroy
    Resque.inline = false
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
    @account.user_emails.find_all_by_user_id(@user1.id).size.should eql 4
  end

  it "should search all except source contact" do
    get :search, :id => @user1.id, :v => "a"
    response.body.should_not =~ /#{@user1.name}/
    response.body.should =~ /Rachel/
  end

  it "should not pass new contact merge for agent" do
    post :new, :id => @agent.id
    response.status.should eql "422 Unprocessable Entity"
  end

end