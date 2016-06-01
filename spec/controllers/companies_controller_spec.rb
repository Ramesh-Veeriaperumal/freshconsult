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
                    :delta, :import_id, :domains, :custom_field  ]

  it "should create a new company" do
    # fails 'cause of recent hack - prefixing and suffixing domains with comma
    #pending("pending relese")
    company = fake_a_company
    post :create, company
    created_company = @account.companies.find_by_name(@company_name)
    created_company.should be_an_instance_of(Company)
    company_attributes(created_company, SKIPPED_KEYS).should be_eql(company[:company])
  end

  it "should quick-create a company" do
    quick_company_name = Faker::Company.name
    post :quick, :company => { :name => quick_company_name }
    flash[:notice].should =~ /Company was successfully created./
    created_company = @account.companies.find_by_name(quick_company_name)
    created_company.should be_an_instance_of(Company)
    created_company.name.should be_eql(quick_company_name)
  end

  it "should update a company" do
    # fails 'cause of recent hack - prefixing and suffixing domains with comma
    #pending("pending relese")
    company = create_company
    another_company = fake_a_company
    put :update, another_company.merge(:id => company.id)

    updated_company = @account.companies.find_by_name(@company_name)
    updated_company.should be_an_instance_of(Company)
    company_attributes(updated_company, SKIPPED_KEYS).should be_eql(another_company[:company])
  end

  it "should create a new company with domains" do
    company = fake_a_company
    company_domain = Faker::Internet.domain_name
    company[:company][:domains] = company_domain
    post :create, company

    created_company = @account.companies.find_by_name(@company_name)
    created_company.should be_an_instance_of(Company)
    created_company.domains.should be_eql(company_domain)
  end

  it "should update the company domains" do
    company = fake_a_company
    company_domain = Faker::Internet.domain_name
    company[:company][:domains] = company_domain
    post :create, company
    created_company = @account.companies.find_by_name(@company_name)

    another_domain = Faker::Internet.domain_name
    company[:company][:domains] = another_domain
    put :update, company.merge(:id => created_company.id)

    updated_company = @account.companies.find_by_name(@company_name)
    updated_company.should be_an_instance_of(Company)
    updated_company.domains.should be_eql(another_domain)
  end

  it "should remove the company domains" do
    company = fake_a_company
    company_domain = Faker::Internet.domain_name
    company[:company][:domains] = company_domain
    post :create, company
    created_company = @account.companies.find_by_name(@company_name)

    company[:company][:domains] = ""
    put :update, company.merge(:id => created_company.id)

    updated_company = @account.companies.find_by_name(@company_name)
    updated_company.should be_an_instance_of(Company)
    updated_company.domains.should be_empty
  end

  it "should list all the created companies on the index page" do
    company = create_company
    get :index
    response.should render_template 'companies/index'
    response.body.should =~ /#{company.name}/
  end

  it "should display the company information on the show page" do
    company = create_company
    get :show, :id => company.id
    response.should render_template 'companies/newshow'
    response.body.should =~ /Recent tickets raised by company contacts/
  end

  it "should display the sla_policy associated with the company on the show page" do
    company = create_company
    agent = add_test_agent(@account)
    sla_policy = create_sla_policy(agent)
    sla_policy.conditions["company_id"] = [company.id]
    sla_policy.save
    get :sla_policies, :id => company.id
    sla_policy.name.all?{|x| response.body.should =~ /#{x}/}
    response.should be_success
  end

  it "should export csv" do
    Resque.inline = true
    post :export_csv, "data_hash"=>"", "export_fields"=>{"Company Name"=>"name", "Description" => "description"}
    data_export = @account.data_exports.last
    data_export.source.should eql 4
    data_export.status.should eql 4
    Resque.inline = false
  end
end