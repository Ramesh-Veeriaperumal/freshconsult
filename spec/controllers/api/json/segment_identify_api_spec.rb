require 'spec_helper'

describe Segment::IdentifyController do
	self.use_transactional_fixtures = false
	include APIAuthHelper

	before(:each) do
		request.host = @account.full_domain
		http_login(@agent)

	end

	after(:all) do
		@new_company.destroy
	end

	it "should create a contact if email doesn't exist" do
        fake_a_contact
		post :create, @params.merge!(:format => 'json'), :content_type => 'application/json'
		result = parse_json(response)
		expected = (response.status == 200) && (compare(result["user"].keys,APIHelper::CONTACT_ATTRIBS,{}).empty?)
		expect(expected).to eq(true)
	end

	it "should create a contact if email exists" do
        existing_contact = get_default_user
        @params = {:user => {:name =>  Faker::Name.name, :email => existing_contact.email}}
		post :create, @params.merge!(:format => 'json'), :content_type => 'application/json'
		expected = (response.status == 200) && response.body.blank?
		expect(expected).to eq(true)
	end

end
		
