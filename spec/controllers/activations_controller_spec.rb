require 'spec_helper'

describe ActivationsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @key_state = mue_key_state(@account)
    enable_mue_key(@account)
    @account.features.multiple_user_emails.create
    @user2 = add_user_with_multiple_emails(@account, 4)
  end

  after(:all) do
    @account.features.multiple_user_emails.destroy
    disable_mue_key(@account) unless @key_state
  end

  it "should send invite to user" do
    login_admin
    u = add_new_user(@account)
    put :send_invite, :id => u.id
    session["flash"][:notice].should eql "Activation email has been sent!"
    Delayed::Job.last.handler.should include("user_activation")
  end

  it "should send invite to user js" do
    login_admin
    u = add_new_user(@account)
    put :send_invite, :id => u.id, :format => 'js'
    response.body.should =~ /activation_sent/
    Delayed::Job.last.handler.should include("user_activation")
  end

  it "should accept to new activation" do
    u = add_new_user(@account)
    u.active = false
    u.save
    get :new, :activation_code => u.perishable_token
    response.body.should =~ /<h3 class="heading">Activate your account /
  end

  it "should not accept the activation" do
    get :new, :activation_code => "dvfdczxxczxcz9cz9-qwdwedwnqjweqw"
    response.should redirect_to(new_password_reset_path)
    session["flash"][:notice].should eql "Your activation code has been expired!"
  end

  it "should activate new email" do
    @account.features.contact_merge_ui.create
    u = add_user_with_multiple_emails(@account, 4)
    u.active = false
    u.save!
    u.reload
    get :new_email, :activation_code => u.user_emails.first.perishable_token
    response.body.should =~ /<h3 class="heading">Activate your account /
    @account.features.contact_merge_ui.destroy
  end

  it "should not activate for no email" do
    @account.features.contact_merge_ui.create
    get :new_email, :activation_code => 'DFGBDFDFgdfgdfgdfGdfgdGDfGdfgdFGdfg'
    session["flash"][:notice].should eql "Your activation code has been expired!"
    response.should redirect_to(home_index_path)
    @account.features.contact_merge_ui.destroy
  end

  it "should shout message for active user" do
    @account.features.contact_merge_ui.create
    get :new_email, :activation_code => @user2.user_emails.last.perishable_token
    session["flash"][:notice].should eql "New email id has been activated"
    @account.features.contact_merge_ui.destroy
  end

  it "should shout message for active user and active email" do
    @user2.primary_email.update_attributes({:verified => true})
    get :new_email, :activation_code => @user2.primary_email.perishable_token
    session["flash"][:notice].should eql "email id already activated"
  end

  it "should create and save passwords" do
    u = add_user_with_multiple_emails(@account, 2)
    u.active = false
    u.save
    u.reload
    post :create, :perishable_token => u.perishable_token, :user=>{:name=>u.name, :password=>"hello", :password_confirmation=>"hello"}
    u.reload
    u.active?.should eql true
    session["flash"][:notice].should eql "Your account has been activated."
  end

  it "should not create activation" do
    post :create, :perishable_token => "dasdasdASDASDasdAsdefsFasDfSdfsdFsDf"
    response.body.should_not =~ /Your account has been activated./
  end
end