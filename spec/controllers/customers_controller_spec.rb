require 'spec_helper'

describe CustomersController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  SKIPPED_KEYS = [  :created_at, :updated_at, :sla_policy_id, :id, :cust_identifier, :account_id, 
                    :delta, :import_id ]

  before(:each) do
    login_admin
  end

  it "should create a new company" do
    company = fake_a_customer
    post :create, company
    created_company = @account.customers.find_by_name(@company_name)
    created_company.should be_an_instance_of(Customer)
    company_attributes(created_company, SKIPPED_KEYS).should be_eql(company[:customer])
  end

  it "should quick-create a company" do
    quick_company_name = Faker::Company.name
    post :quick, :customer => { :name => quick_company_name }
    created_company = @account.customers.find_by_name(quick_company_name)
    created_company.should be_an_instance_of(Customer)
    created_company.name.should be_eql(quick_company_name)
  end

  it "should update a company" do
    company = create_company
    another_company = fake_a_customer
    put :update, another_company.merge(:id => company.id)
    updated_company = @account.customers.find_by_name(@company_name)
    updated_company.should be_an_instance_of(Customer)
    company_attributes(updated_company, SKIPPED_KEYS).should be_eql(another_company[:customer])
  end

  it "should list all the created companies on the index page" do
    company = create_company
    get :index
    response.should render_template 'customers/index'
    response.body.should =~ /#{company.name}/
  end

  it "should display the company information on the show page" do
    company = create_company
    get :show, :id => company.id
    response.should render_template 'customers/show'
    response.body.should =~ /Recent tickets from #{company.name}/
  end

  it "should respond to new" do
    get :new
    response.status.should eql("200 OK")
    response.should render_template 'customers/new'
  end

  it "should respond to edit" do
    company = create_company
    get :edit, :id => company.id
    response.status.should eql("200 OK")
    response.should render_template 'customers/edit'
    company_attributes(company, SKIPPED_KEYS).each do |attribute, value|
      response.body.should =~ /#{value}/
    end
  end
end