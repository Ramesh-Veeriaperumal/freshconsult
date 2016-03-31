require 'spec_helper'

describe CustomersController do
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

  it "should redirect if new action is invoked" do
    get :new
    response.status.should eql(302)
    response.should redirect_to "http://localhost.freshpo.com/companies/new"
  end

  it "should redirect if edit action is invoked" do
    company = create_company
    get :edit, :id => company.id
    response.status.should eql(302)
    response.should redirect_to "http://localhost.freshpo.com/companies/#{company.id}/edit"
  end

  it "should redirect if index action is invoked" do
    get :index
    response.should redirect_to companies_url
  end

  it "should redirect if show action is invoked" do
    company = create_company
    get :show, :id => company.id
    response.should redirect_to company_url(company)
  end

  it "should create a new company(works because the API support is not deprecated yet)" do
    company = fake_a_customer
    post :create, company
    created_company = @account.companies.find_by_name(@company_name)
    created_company.should be_an_instance_of(Company)

    company[:customer][:domains] = ",#{company[:customer][:domains]},"
    company_attributes(created_company, SKIPPED_KEYS).should be_eql(company[:customer])
  end

  it "should update a company(works because the API support is not deprecated yet)" do
    company = create_company
    another_company = fake_a_customer
    put :update, another_company.merge(:id => company.id)

    updated_company = @account.companies.find_by_name(@company_name)
    updated_company.should be_an_instance_of(Company)

    another_company[:customer][:domains] = ",#{another_company[:customer][:domains]},"
    company_attributes(updated_company, SKIPPED_KEYS).should be_eql(another_company[:customer])
  end

  it "should destroy a company(works because the API support is not deprecated yet)" do
    delete :destroy, { :id => company.id }
    expect{ Company.find(@company.id) }.to raise_error(ActiveRecord::RecordNotFound)
    response.status.should eql(302)
    response.should redirect_to "http://localhost.freshpo.com/companies"
    @company = nil
  end

  it "should destroy a list of companies(works because the API support is not deprecated yet)" do
    company1 = create_company
    company2 = create_company
    delete :destroy, { :ids => [company1.id, company2.id] }
    response.status.should eql(302)
    response.should redirect_to "http://localhost.freshpo.com/companies"
    expect{ Company.find(company1.id) }.to raise_error(ActiveRecord::RecordNotFound)
    expect{ Company.find(company2.id) }.to raise_error(ActiveRecord::RecordNotFound)
  end
  
end