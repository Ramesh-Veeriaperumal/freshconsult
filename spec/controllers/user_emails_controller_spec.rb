require 'spec_helper'

describe UserEmailsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @key_state = mue_key_state(@account)
    enable_mue_key(@account)
    @account.features.multiple_user_emails.create
    @account.features.contact_merge_ui.create
    @userUEC = add_user_with_multiple_emails(@account, 4)
  end

  before(:each) do
    login_admin
  end

  after(:all) do
    @account.features.contact_merge_ui.destroy
    @account.features.multiple_user_emails.destroy
    disable_mue_key(@account) unless @key_state
  end

  it "should make email primary" do
    @userUEC.user_emails.first.update_attributes({:verified => true})
    @userUEC.user_emails.last.update_attributes({:verified => true})
    last_id = @userUEC.user_emails.last.id
    get :make_primary, :id => @userUEC.id, :email_id => last_id
    @userUEC.user_emails.find(:all, :conditions => {:user_id => @userUEC.id, :primary_role => true}).first.id.should eql last_id
  end

  # it "should not make email primary" do
  #   get :make_primary, :id => "511", :email_id => "12"
  #   response.body.should =~ /Failed to change default E-Mail/
  # end

  it "should send user verification" do
    usernew = add_user_with_multiple_emails(@account, 2)
    Delayed::Job.delete_all
    put :send_verification, :email_id => usernew.user_emails.last.id
    response.body.should =~ /Activation mail sent./
    Delayed::Job.last.handler.should include("email_activation")
  end

end