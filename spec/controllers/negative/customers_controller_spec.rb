require 'spec_helper'

describe CustomersController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    login_admin
  end

  SKIPPED_KEYS = [  :created_at, :updated_at, :sla_policy_id, :id, :cust_identifier, :account_id, 
                    :delta, :import_id ]

  it "should not create a new company without a name" do
    post :create, :customer => {  :name => "", 
                                  :description => Faker::Lorem.sentence(3), 
                                  :note => "", 
                                  :domains => ""
                                 }
    response.body.should =~ /Name can&#39;t be blank/
  end

  it "should not create a new company with the same name" do
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

  it 'should not quick-create a company with same name' do
    company_name = Faker::Company.name
    post :quick, :customer => {:name => company_name}
    flash[:notice].should =~ /The company has been created/
    post :quick, :customer => {:name => company_name}
    flash[:notice].should =~ /Name has already been taken/
  end

  it "should update a company ensuring unique name" do
    company = create_company
    another_company = create_company
    put :update, {:customer => company_attributes(company, SKIPPED_KEYS)}.merge(:id => another_company.id)
    response.body.should =~ /Name has already been taken/
  end
end