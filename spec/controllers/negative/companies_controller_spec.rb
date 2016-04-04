require 'spec_helper'

describe CompaniesController do
  # integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account.companies.each &:destroy
  end

  before(:each) do
    login_admin
  end

  SKIPPED_KEYS = [  :created_at, :updated_at, :sla_policy_id, :id, :cust_identifier, :account_id, 
                    :delta, :import_id ]

  it "should not create a new company without a name" do
    post :create, :company => {   :name => "", 
                                  :description => Faker::Lorem.sentence(3), 
                                  :note => "", 
                                  :domains => ""
                                 }
    response.body.should =~ /Name can&#x27;t be blank/
  end

  it "should not create a new company with the same name" do
    company_name = Faker::Company.name
    post :create, :company => { :name => company_name, 
                                :description => Faker::Lorem.sentence(3), 
                                :note => "", 
                                :domains => ""
                              }
    post :create, :company => { :name => company_name, 
                                :description => Faker::Lorem.sentence(3), 
                                :note => "", 
                                :domains => ""
                              }
    response.body.should =~ /Name has already been taken/
  end


  it 'should not quick-create a company with same name' do
    company_name = Faker::Company.name
    post :quick, :company => {:name => company_name}
    flash[:notice].should =~ /Company was successfully created./
    post :quick, :company => {:name => company_name}
    flash[:notice].should =~ /Name has already been taken/
  end

  it "should not update a company without a unique name" do
    company = create_company
    another_company = create_company
    put :update, {:company => company_attributes(company, SKIPPED_KEYS)}.merge(:id => another_company.id)
    response.body.should =~ /Name has already been taken/
  end
end