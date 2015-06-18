require 'spec_helper'

describe Segment::IdentifyController do
	self.use_transactional_fixtures = false
	include APIAuthHelper

	before(:each) do
		request.host = @account.full_domain
		http_login(@agent)

	end

	it "should create a contact if email doesn't exist" do
        fake_a_contact
		post :create, @params.merge!(:format => 'json', :type => 'identify'), :content_type => 'application/json'
		result = parse_json(response)
		expected = (response.status == 200) && (compare(result["user"].keys,APIHelper::CONTACT_ATTRIBS,{}).empty?)
		expect(expected).to eq(true)
	end

	it "should update a contact if email exists" do
        existing_contact = get_default_user
        @params = {:user => {:name =>  Faker::Name.name, :email => existing_contact.email}}
		post :create, @params.merge!(:format => 'json', :type => 'identify'), :content_type => 'application/json'
		expected = (response.status == 200) && response.body.blank?
		expect(expected).to eq(true)
	end
  
	it "should update address field as string" do
        fake_a_contact
        user_address_params
        @params[:user][:address] = @address_param
		post :create, @params.merge!(:format => 'json', :type => 'identify'), :content_type => 'application/json'
		result = parse_json(response)
		expected = (response.status == 200) && (compare(result["user"].keys,APIHelper::CONTACT_ATTRIBS,{}).empty?) && result["user"]["address"] == expected_address
		expect(expected).to eq(true)
	end

	it "should not create a contact if email is blank" do
        fake_a_contact
        @params[:user].delete(:email)
		post :create, @params.merge!(:format => 'json', :type => 'identify'), :content_type => 'application/json'
		result = parse_json(response)
		expected = (response.status == 400) && result["message"] == "Email can't be blank"
		expect(expected).to eq(true)
	end

	it "should not create a contact if email is invalid" do
        fake_a_contact
        @params[:user][:email] = Faker::Name.name
		post :create, @params.merge!(:format => 'json', :type => 'identify'), :content_type => 'application/json'
		result = parse_json(response)
		expected = (response.status == 400) && result == invalid_email_response
		expect(expected).to eq(true)
	end

	def expected_address
      str = ""
      @address_param.each{|k,v| str << "#{k}:#{v}\n"}
      str
	end

	def invalid_email_response
      response = { "primary_email.email" => ["is invalid"], "base" => ["Email is invalid"] }
	end

end
		
