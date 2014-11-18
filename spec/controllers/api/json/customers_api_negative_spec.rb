require 'spec_helper'

RSpec.describe CustomersController do
  self.use_transactional_fixtures = false

  before(:each) do
    request.host = @account.full_domain
    http_login(@agent)
  end


  it "should not create a new company without a name" do
    post :create, {:customer => {  :name => "", 
                                  :description => Faker::Lorem.sentence(3), 
                                  :note => "", 
                                  :domains => ""
                                 },:format => 'json' }
    error_status?(response.status) && name_blank?(response)
  end

  it "should not create a new company with the same name" do
    company_name = Faker::Lorem.sentence(3)
    post :create, {:customer => {  :name => company_name, 
                                  :description => Faker::Lorem.sentence(3), 
                                  :note => "", 
                                  :domains => ""
                                 },:format => 'json'}
    post :create, { :customer => {  :name => company_name, 
                                  :description => Faker::Lorem.sentence(3), 
                                  :note => "", 
                                  :domains => ""
                                 },:format => 'json'}
    error_status?(response.status)  &&  duplicate_name?(response)
  end

  it "should not allow to update an empty customer name to any existing customer" do
    company_name = Faker::Lorem.sentence(2)
    company = FactoryGirl.build(:company, :name => company_name)
    company.save
    put :update, { :id=>company.id ,:customer => { :name => "" }, :format => 'json'}
    error_status?(response.status) && name_blank?(response)
  end

  it "should not allow to update an existing customer name to any other customer" do
    company_name = Faker::Lorem.sentence(2)
    company = FactoryGirl.build(:company, :name => company_name)
    company.save
    second_company = FactoryGirl.build(:company, :name => Faker::Lorem.sentence(3))
    second_company.save
    put :update, { :id=>second_company.id ,:customer => { :name => company_name }, :format => 'json'}
    error_status?(response.status) && duplicate_name?(response)
  end

    def error_status?(status)
      status =~ /422/ 
    end

    def name_blank?(response)
      json = parse_json(response)
      json.join(" ").should =~ /name can't be blank/
    end

    def duplicate_name?(response)
      json = parse_json(response)
      json.join(" ").should =~ /name has already been taken/
    end

end