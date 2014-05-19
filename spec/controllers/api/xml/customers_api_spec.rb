require 'spec_helper'

describe CustomersController do

  SKIPPED_KEYS = [  :created_at, :updated_at, :sla_policy_id, :id, :cust_identifier, :account_id, 
                    :delta, :import_id ]

  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account = create_test_account
    @user = add_test_agent(@account)
  end

  before(:each) do
    @request.host = @account.full_domain
    @request.user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36 
                                        (KHTML, like Gecko) Chrome/32.0.1700.107 Safari/537.36"
    log_in(@user)
    clear_xml
  end

  # CompaniesController Xml and Json Index Actions and filter actions, require Elastic Search. 
  # ES updates over resque which has to happen inline and many issues in consistency 
  # between data in ES and SQL. So not writing test cases involving ES.

  it "should create a new company using the API" do
    fake_a_customer
    post :create, @params.merge!(:format => 'xml')
    @comp = @account.customers.find_by_name(@company_name)
    response.status.should be_eql '201 Created'
    response.location.should be_eql "http://localhost.freshpo.com/customers/#{@comp.id}"
    @company_params.should be_eql(xml SKIPPED_KEYS)
  end

  it "should fetch a company using the API" do
    get :show, { :id => company.id, :format => 'xml' }
    xml SKIPPED_KEYS
    { :customer => company_attributes(company, SKIPPED_KEYS) }.should be_eql(xml)
  end

  it "should update a company using the API" do
    id = company.id
    fake_a_customer
    put :update, (@params).merge!({ :id => id, :format => 'xml' })
    { :customer => company_attributes(@account.customers.find(id), SKIPPED_KEYS) }.
                                                                    should be_eql(@company_params)
  end

  it "should delete a company using the API" do
    delete :destroy, { :id => company.id, :format => 'xml' }
    xml SKIPPED_KEYS
    { :customers => [company_attributes(@company, SKIPPED_KEYS)] }.should be_eql(xml)
    @company = nil
  end

  it "should delete multiple companies using the API" do
    another_company = create_company
    delete :destroy, { :ids => [company.id, another_company.id], :format => 'xml' }
    xml SKIPPED_KEYS
    { :customers => [ company_attributes(@company, SKIPPED_KEYS), 
                      company_attributes(another_company, SKIPPED_KEYS) ] }.should be_eql(xml)
    @company = nil
  end

  # Can't restore a deleted company, its a hard delete
end