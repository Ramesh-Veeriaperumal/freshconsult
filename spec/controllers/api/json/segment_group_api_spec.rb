require 'spec_helper'

describe Segment::GroupController do
	self.use_transactional_fixtures = false
	include APIAuthHelper

	before(:each) do
		request.host = @account.full_domain
		http_login(@agent)

	end

	it "should create a company if name doesn't exist" do
        fake_a_company
		post :create, @params.merge!(:format => 'json', :type => 'group'), :content_type => 'application/json'
		result = parse_json(response)
		expected = (response.status == 200) && compare(result['company'].keys,APIHelper::COMPANY_ATTRIBS,{}).empty?
		expect(expected).to eq(true)
	end

	it "should update a company if name exists" do
        existing_company = get_default_company
        @params = {:company => {:description =>  Faker::Lorem.sentence, :name => existing_company.name}}
		post :create, @params.merge!(:format => 'json', :type => 'group'), :content_type => 'application/json'
		expected = (response.status == 200) && response.body.blank?
		expect(expected).to eq(true)
	end

	it "should return 501 if type does not match" do
        fake_a_company
		post :create, @params.merge!(:format => 'json'), :content_type => 'application/json'
		result = parse_json(response)
		expected = (response.status == 501)  && result["message"].should == I18n.t('contacts.segment_api.invalid_type')
		expect(expected).to eq(true)
	end

	it "should not create a company if name is blank" do
        fake_a_company
        @params[:company].delete(:name)
		post :create, @params.merge!(:format => 'json', :type => 'group'), :content_type => 'application/json'
		result = parse_json(response)
		expected = (response.status == 400) && result == blank_name_response
		expect(expected).to eq(true)
	end

	def blank_name_response
     response = { "name"=> ["can't be blank"], "Company name" => ["cannot be blank"]}
	end

end
		
