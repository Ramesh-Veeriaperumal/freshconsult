require 'spec_helper'

describe Helpdesk::SlaPoliciesController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @now = (Time.now.to_f*1000).to_i
    @sla_policy_1 = create_sla_policy(@agent)
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
    @sla_policy_1.destroy
    @new_company_1.destroy
    @new_company_2.destroy
  end

  it "should list all sla_policies on index action" do
    get :index, :format => 'json'
    result = parse_json(response)
    expected = (response.status == 200) && (compare(result.first["helpdesk_sla_policy"].keys,APIHelper::SLA_POLICY_ATTRIBS,{}).empty?)
    expected.should be(true)
  end

  it "should udpate companys' SLA policies" do
    put :company_sla, { :helpdesk_sla_policy => { :conditions => { :company_id => "#{@new_company_1.id}"}},
                                :id => @sla_policy_1.id,
                                :format => 'json' },
                                :content_type => 'application/json'
    result =  parse_json(response)
    expected = (response.status == 200) && (result["helpdesk_sla_policy"]["conditions"]["company_id"].include? @new_company_1.id)   
    expected.should be(true)
    @account.sla_policies.find(@sla_policy_1.id).conditions[:company_id].join(',').should eql("#{@new_company_1.id}")
  end

  it "should udpate multiple companys' SLA policies" do
    put :company_sla, { :helpdesk_sla_policy => { :conditions => { :company_id => "#{@new_company_1.id},#{@new_company_2.id}"}},
                                :id => @sla_policy_1.id,
                                :format => 'json' },
                              :content_type => 'application/json'
    result =  parse_json(response)
    expected = (response.status == 200) && (result["helpdesk_sla_policy"]["conditions"]["company_id"].include? @new_company_2.id)
    expected.should be(true)
    @account.sla_policies.find(@sla_policy_1.id).conditions[:company_id].sort.join(',').should eql("#{@new_company_1.id},#{@new_company_2.id}")
  end

  it "should not update defualt SLA policy" do
    put :company_sla, { :helpdesk_sla_policy => { :conditions => { :company_id => "#{@new_company_1.id}"}},
                                :id =>  @account.sla_policies.default.first.id,
                                :format => 'json' },
                              :content_type => 'application/json'
    result =  parse_json(response)
    expected = (response.status == 400) && result == error_response(I18n.t('sla_policy.update_company_sla_api.default_policy_update'), I18n.t('sla_policy.update_company_sla_api.update_failed') )
    expected.should be(true)
  end

  it "should not update other conditions" do
    put :company_sla, { :helpdesk_sla_policy => { :conditions => { :company_id => "#{@new_company_1.id}", :group_id => "1"}},
                                :id =>   @sla_policy_1.id,
                                :format => 'json' },
                              :content_type => 'application/json'
    result =  parse_json(response)
    expected = (response.status == 400) && result == error_response(I18n.t('sla_policy.update_company_sla_api.invalid_arguments_for_update'), I18n.t('sla_policy.update_company_sla_api.update_failed') )
    expected.should be(true)
  end


  it "should not update on invalid input params" do
    put :company_sla, { :helpdesk_sla_policy => { :conditions  => "#{@new_company_1.id}"},
                                :id =>  @sla_policy_1.id,
                                :format => 'json' },
                              :content_type => 'application/json'
    result =  parse_json(response)
    expected = (response.status == 400) && result == error_response(I18n.t('sla_policy.update_company_sla_api.invalid_arguments_for_update'), I18n.t('sla_policy.update_company_sla_api.update_failed') )
    expected.should be(true)
  end

  it "should not update on invalid data type on input params" do
    put :company_sla, { :helpdesk_sla_policy => { :conditions  => { :company_id => [@new_company_1.id]}},
                                :id =>  @sla_policy_1.id,
                                :format => 'json' },
                              :content_type => 'application/json'
    result =  parse_json(response)
    expected = (response.status == 400) && result == error_response(I18n.t('sla_policy.update_company_sla_api.invalid_data_type'), I18n.t('sla_policy.update_company_sla_api.update_failed'))
    expected.should be(true)
  end

  def error_response(message, error)
    {
      "errors" => [
        {
           "message" => message,
           "error" => error

        }
      ]
    }
  end
end