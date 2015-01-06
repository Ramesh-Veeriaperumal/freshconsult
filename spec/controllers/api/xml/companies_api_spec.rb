require 'spec_helper'

describe CompaniesController do

  SKIPPED_KEYS = [  :created_at, :updated_at, :sla_policy_id, :id, :cust_identifier, :account_id, 
                    :delta, :import_id,:custom_field ]

  # integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    #@account = create_test_account
    @user = add_test_agent(@account)
    @account.companies.destroy
    @company = company
  end

  before(:each) do
    @request.host = @account.full_domain
    @request.user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36 
                                        (KHTML, like Gecko) Chrome/32.0.1700.107 Safari/537.36"
    http_login(@user)
    clear_xml
  end

  # CompaniesController Xml and Json Index Actions and filter actions, require Elastic Search. 
  # ES updates over resque which has to happen inline and many issues in consistency 
  # between data in ES and SQL. So not writing test cases involving ES.

  it "should create a new company using the API" do
    fake_a_company
    post :create, @params.merge!(:format => 'xml')
    @comp = @account.companies.find_by_name(@company_name)
    response.status.should be_eql 201
    response.location.should be_eql "http://localhost.freshpo.com/companies/#{@comp.id}"
    result =  parse_xml(response)
    expected = compare(result['company'].keys,APIHelper::COMPANY_ATTRIBS,{}).empty?
    expected.should be(true)
  end

  it "should fetch a company using the API" do
    get :show, { :id => @company.id, :format => 'xml' }
    result =  parse_xml(response)
    expected = compare(result['company'].keys,APIHelper::COMPANY_ATTRIBS,{}).empty?
    expected.should be(true)
  end

  it "should update a company using the API" do
    id = @company.id
    fake_a_company
    put :update, (@params).merge!({ :id => id, :format => 'xml' })
    { :company => company_attributes(@account.companies.find(id), SKIPPED_KEYS) }.
                                                                    should be_eql(@company_params)
  end

  it "should delete a company using the API" do
    delete :destroy, { :id => @company.id, :format => 'xml' }
    xml SKIPPED_KEYS
    response.status == 200
    # { :companies => [company_attributes(@company, SKIPPED_KEYS)] }.should be_eql(xml)
    # @company = nil
  end

  it "should delete multiple companies using the API" do
    another_company = create_company
    delete :destroy, { :ids => [@company.id, another_company.id], :format => 'xml' }
    xml SKIPPED_KEYS
    response.status == 200
    # { :companies => [ company_attributes(@company, SKIPPED_KEYS), 
                      # company_attributes(another_company, SKIPPED_KEYS) ] }.should be_eql(xml)
    # @company = nil
  end

  # Can't restore a deleted company, its a hard delete
end