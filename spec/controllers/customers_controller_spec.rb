require 'spec_helper'

describe CustomersController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    log_in(@user)
  end

  it "should create a new company" do
    test_company_name = Faker::Lorem.sentence(3)
    post :create, :customer => { :name => test_company_name, 
                                  :description => Faker::Lorem.sentence, 
                                  :note => "", 
                                  :domains => ""
                                 }
    @account.customers.find_by_name(test_company_name).should be_an_instance_of(Customer)
  end

  it "should quick-create a company" do
    quick_company_name = Faker::Lorem.sentence(3)
    post :quick, :customer => { :name => quick_company_name }
    @account.customers.find_by_name(quick_company_name).should be_an_instance_of(Customer)
  end

  it "should edit a company" do
    customer = Factory.build(:customer, :name => Faker::Lorem.sentence(2))
    customer.save
    company_name = Faker::Lorem.sentence(3)
    put :update, :id => customer.id,  :customer => {:name => company_name, 
                                                    :description => Faker::Lorem.sentence, 
                                                    :note => "", 
                                                    :domains => ""
                                                   }
    @account.customers.find_by_name(company_name).should be_an_instance_of(Customer)
  end

  it "should list all the created companies on the index page" do
    customer = Factory.build(:customer, :name => "Freshdesk Inc.")
    customer.save
    get :index
    response.should render_template 'customers/index'
    response.body.should =~ /Freshdesk Inc./
  end

  it "should display the company information on the show page" do
    customer = Factory.build(:customer, :name => "Freshservice")
    customer.save
    get :show, :id => customer.id
    response.should render_template 'customers/show'
    response.body.should =~ /Recent tickets from Freshservice/
  end
end