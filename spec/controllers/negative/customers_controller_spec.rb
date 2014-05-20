require 'spec_helper'

describe CustomersController do
  integrate_views
  setup :activate_authlogic

  before(:each) do
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