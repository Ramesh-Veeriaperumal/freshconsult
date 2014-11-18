require 'spec_helper'

RSpec.describe CustomersController do
  self.use_transactional_fixtures = false


  before(:each) do
    request.host = @account.full_domain
    http_login(@agent)
  end

  it "should not create a new company without a name" do
    fake_a_customer
    @params[:customer].merge!(:name => "") 
    post :create, @params.merge!(:format => 'xml'), :content_type => 'application/xml'
    error_status?(response.status).should be_truthy
  end

  it "should not create a new company with the same name" do
    fake_a_customer
    post :create, @params.merge!(:format => 'xml'), :content_type => 'application/xml'
    post :create, @params.merge!(:format => 'xml'), :content_type => 'application/xml'
    error_status?(response.status).should be_truthy
  end

  it "should not allow to update an empty customer name to any existing customer" do
    company_name = Faker::Lorem.sentence(2)
    company = FactoryGirl.build(:company, :name => company_name)
    company.save
    put :update, { :id=>company.id ,:customer => { :name => "" }, :format => 'xml'},  :content_type => 'application/xml'
    error_status?(response.status).should be_truthy
  end

  it "should not allow to update an existing customer name to any other customer" do
    company_name = Faker::Lorem.sentence(2)
    company = FactoryGirl.build(:company, :name => company_name)
    company.save
    second_company = FactoryGirl.build(:company, :name => Faker::Lorem.sentence(3))
    second_company.save
    put :update, { :id=>second_company.id ,:customer => { :name => company_name }, :format => 'xml'}, :content_type => 'application/xml'
    error_status?(response.status).should be_truthy
  end

    def error_status?(status)
      status == 422
    end
    
end