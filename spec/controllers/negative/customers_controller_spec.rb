require 'spec_helper'

RSpec.describe CustomersController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account.companies.each &:destroy
  end

  before(:each) do
    request.env["HTTP_ACCEPT"] = "application/xml"
    login_admin
  end

  SKIPPED_KEYS = [  :created_at, :updated_at, :sla_policy_id, :id, :cust_identifier, :account_id, 
                    :delta, :import_id ]

  it "should not create a new company without a name(works because the API support is not deprecated yet)" do
    post :create, :customer => {  :name => "", 
                                  :description => Faker::Lorem.sentence(3), 
                                  :note => "", 
                                  :domains => ""
                                 }
    response.body.should =~ /Name can't be blank/
  end

  it "should not create two companies with the same name(works because the API support is not deprecated yet)" do
    company_name = Faker::Company.name
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

  it "should not update a company with a non-unique name(works because the API support is not deprecated yet)" do
    company = create_company
    another_company = create_company
    put :update, {:customer => company_attributes(company, SKIPPED_KEYS)}.merge(:id => another_company.id)
    response.body.should =~ /Name has already been taken/
  end
end