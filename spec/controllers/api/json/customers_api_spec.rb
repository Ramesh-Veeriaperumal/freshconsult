require 'spec_helper'

describe CustomersController do

  SKIPPED_KEYS = [  :created_at, :updated_at, :sla_policy_id, :id, :cust_identifier, :account_id, 
                    :delta, :import_id,:custom_field ]

  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @comp = create_company
  end

  before(:each) do
    login_admin
    clear_json
  end

  after(:all) do
    @comp.destroy
  end

  # CompaniesController Xml and Json Index Actions and filter actions, require Elastic Search. 
  # ES updates over resque which has to happen inline and many issues in consistency 
  # between data in ES and SQL. So not writing test cases involving ES.

  it "should create a new company using the API" do
    fake_a_customer
    post :create, @params.merge!(:format => 'json')
    @comp = @account.companies.find_by_name(@company_name)
    result =  parse_json(response)
    expected = (response.status == 201) && compare(result['customer'].keys,APIHelper::COMPANY_ATTRIBS,{}).empty?
    expected.should be(true)
  end

  it "should fetch a company using the API" do
    id = @account.companies.find_by_name(@comp.name).id
    get :show, { :id => id, :format => 'json' }
    result =  parse_json(response)
    expected = compare(result['customer'].keys,APIHelper::COMPANY_ATTRIBS,{}).empty?
    expected.should be(true)
  end

  it "should update a company using the API" do
    id = @account.companies.find_by_name(@comp.name).id
    fake_a_customer
    put :update, (@params).merge!({ :id => id, :format => 'json' })
    { :customer => company_attributes(@account.companies.find(id), SKIPPED_KEYS) }.
                                                                    should be_eql(@company_params)
  end

  it "should delete a company using the API" do
    @comp = create_company
    id = @account.companies.find_by_name(@comp.name).id
    delete :destroy, { :id => id, :format => 'json' }
    response.status.should be_eql(200)
    @company = nil
  end

  it "should delete multiple companies using the API" do
    @comp = create_company
    id = @account.companies.find_by_name(@comp.name).id
    @another_comp = create_company
    another_id = @account.companies.find_by_name(@another_comp.name).id
    delete :destroy, { :ids => [id, another_id], :format => 'json' }
    response.status.should be_eql(200)
    @company = nil
  end

  # Can't restore a deleted company, its a hard delete
end