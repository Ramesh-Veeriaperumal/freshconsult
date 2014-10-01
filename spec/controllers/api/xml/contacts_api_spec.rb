require 'spec_helper'

RSpec.configure do |c|
  c.include APIAuthHelper
end

#Test cases for json api calls to contacts.
RSpec.describe ContactsController do
  self.use_transactional_fixtures = false


  before(:each) do
    request.host = RSpec.configuration.account.full_domain
    http_login(RSpec.configuration.agent)
  end

	it "should create a contact" do 
		fake_a_contact
		post :create, @params.merge!(:format => 'xml'), :content_type => 'application/xml'
		#api impl gives out 200 status, change this when its fixed to return '201 created'
	 	result = parse_xml(response)
	 	expected = (response.status == 201) && (compare(result["user"].keys,APIHelper::CONTACT_ATTRIBS,{}).empty?)
	 	expected.should be(true)
	end

	it "should show an existing contact" do
		contact = add_new_user(RSpec.configuration.account,{})
		get :show, {:id => contact.id, :format => 'xml'}
	 	result = parse_xml(response)
	 	expected = (response.status == 200) && (compare(result["user"].keys,APIHelper::CONTACT_ATTRIBS,{}).empty?)
	 	expected.should be(true)
	end

	it "should update an existing contact" do
		contact = add_new_user(RSpec.configuration.account,{})
    test_email = Faker::Internet.email
    test_phone_no = Faker::PhoneNumber.phone_number
    put :update, {:id => contact.id, :user => { :email => test_email, 
                                                :job_title => "Developer",
                                                :phone => test_phone_no,
                                                :time_zone => contact.time_zone, 
                                                :language => contact.language },:format => 'xml'}
	 	response.status.should eql(200)
	end

	it "should delete an existing contact" do
		contact = add_new_user(RSpec.configuration.account,{})
		delete :destroy, {:id => contact.id, :format => 'xml'}
		response.status.should be_eql(200)		
	end

	it "should fetch contacts filtered by email" do
		contact = add_new_user(RSpec.configuration.account,{})
	 	check_email  = contact.email
	 	get :index, {:query=>"email is #{check_email}", :state=>:all, :format => 'xml'}
	 	result = parse_xml(response)
	 	expected = (response.status == 200) && (compare(result["users"].first.keys,APIHelper::CONTACT_ATTRIBS,{}).empty?)
	 	expected.should be(true)
	end

	it "should fetch contacts filtered by phone" do
		# phone/mobile filter now searches only valid numerics: 1231234
		# US numbers format is not searched 812.123.1232 or (802)-123-1232
		# Hence not using Faker for phonenumber generation.
		# This needs to be addressed. change filter expresssion in api_helper_methods
		contact = FactoryGirl.build(:user, :account => RSpec.configuration.account,
                                    :name => Faker::Name.name, 
                                    :email => Faker::Internet.email,
                                    :phone => 42345678,
                                    :time_zone => "Chennai", 
                                    :delta => 1, 
                                    :language => "en")
    contact.save(validate: false)
	 	check_phone  = contact.phone
	 	get :index, {:query=>"phone is #{check_phone}", :state=>:all, :format => 'xml'}
	 	result = parse_xml(response)
	 	expected = (response.status == 200) && (compare(result["users"].first.keys,APIHelper::CONTACT_ATTRIBS,{}).empty?)
	 	expected.should be(true)
	end

	it "should fetch contacts filtered by mobile" do
		# This needs to be addressed. change filter expresssion in api_helper_methods
		contact = FactoryGirl.build(:user, :account => RSpec.configuration.account,
                                    :name => Faker::Name.name, 
                                    :email => Faker::Internet.email,
                                    :mobile => 9876543210,
                                    :time_zone => "Chennai", 
                                    :delta => 1, 
                                    :language => "en")
		contact.save(validate: false)
	 	check_mobile  = contact.mobile
	 	get :index, {:query=>"mobile is #{check_mobile}", :state=>:all, :format => 'xml'}
	 	result = parse_xml(response)
	 	expected = (response.status == 200) && (compare(result["users"].first.keys,APIHelper::CONTACT_ATTRIBS,{}).empty?)
	 	expected.should be(true)
	end

  it "should fetch contacts filtered by company id" do
    new_company = FactoryGirl.build(:customer, :name => Faker::Name.name)
    new_company.save
    contact = FactoryGirl.build(:user, :account => @account,
                                    :name => Faker::Name.name, 
                                    :email => Faker::Internet.email,
                                    :mobile => 9876543210,
                                    :time_zone => "Chennai", 
                                    :delta => 1, 
                                    :language => "en",
                                    :customer_id => new_company.id)
    contact.save(validate: false)
    check_id  = new_company.id
    get :index, {:query=>"customer_id is #{check_id}", :state=>:all, :format => 'xml'}
    result = parse_xml(response)
    expected = (response.status == 200) && (compare(result["users"].first.keys,APIHelper::CONTACT_ATTRIBS,{}).empty?)
    expected.should be(true)
  end

end