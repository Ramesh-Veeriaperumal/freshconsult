require 'spec_helper'

describe CustomersController do
  integrate_views
  setup :activate_authlogic

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

  it "should not create a new company without a name" do
    post :create, :customer => {  :name => "", 
                                  :description => Faker::Lorem.sentence(3), 
                                  :note => "", 
                                  :domains => ""
                                 }
    response.body.should =~ /Name can&#39;t be blank/
  end

  it "should not create a new company with the same name" do
    company_name = Faker::Lorem.sentence(3)
    post :create, :customer => {  :name => company_name, 
                                  :description => Faker::Lorem.sentence(3), 
                                  :note => "", 
                                  :domains => ""
                                 }
    post :create, :customer => {  :name => company_name, 
                                  :description => Faker::Lorem.sentence(3), 
                                  :note => "", 
                                  :domains => ""
                                 }
    response.body.should =~ /Name has already been taken/
  end
end