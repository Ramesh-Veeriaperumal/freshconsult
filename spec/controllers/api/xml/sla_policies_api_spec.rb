require 'spec_helper'

describe Helpdesk::SlaPoliciesController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @now = (Time.now.to_f*1000).to_i
    @new_company_1 = FactoryGirl.build(:company, :name => Faker::Name.name)
    @new_company_1.save
    @new_company_1.reload
    @new_company_2 = FactoryGirl.build(:company, :name => Faker::Name.name)
    @new_company_2.save
    @new_company_2.reload
  end

  before(:each) do
    request.host = @account.full_domain
    http_login(@agent)
  end

  after(:all) do
    @new_company_1.destroy
    @new_company_2.destroy
  end

  it "should list all sla_policies on index action" do
    get :index, :format => 'xml'
    result = parse_xml(response)
    expected = (response.status == 200) && (compare(result["helpdesk_sla_policies"].first.keys, APIHelper::SLA_POLICY_ATTRIBS,{}).empty?)
    expected.should be(true)
  end

end