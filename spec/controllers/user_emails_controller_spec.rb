require 'spec_helper'

describe UserEmailsController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account.features.multiple_user_emails.create
    @userUEC = add_user_with_multiple_emails(@account, 4)
  end

  before(:each) do
    login_admin
  end

  after(:all) do
    @account.features.multiple_user_emails.destroy
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
    Delayed::Job.delete_all
    put :send_verification, :email_id => @userUEC.user_emails.second.id
    response.body.should =~ /Activation mail sent./
    Delayed::Job.last.handler.should include("deliver_email_activation")
  end

end