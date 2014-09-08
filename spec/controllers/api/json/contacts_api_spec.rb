require 'spec_helper'


#Test cases for json api calls to contacts.
describe ContactsController do
  self.use_transactional_fixtures = false
  include APIAuthHelper

  before(:each) do
    request.host = RSpec.configuration.account.full_domain
    http_login(RSpec.configuration.agent)
    clear_json
  end

	it "should create a contact" do 
		fake_a_contact
		post :create, @params.merge!(:format => 'json'), :content_type => 'application/json'
	 	# result = parse_json(response)
		#api impl gives out 200 status, change this when its fixed to return '201 created'
	 	#also add helpdesk_agent attrib to json response to be in sync with xml
	 	#&& compare(result["user"],APIHelper::CONTACT_ATTRIBS,{})
	 	response.status.should eql(200)
	end

	it "should show an existing contact" do
		contact = add_new_user(@account,{})
		get :show, {:id => contact.id, :format => 'json'}
	 	result = parse_json(response)
	 	expected = (response.status == 200) && (compare(result["user"].keys,APIHelper::CONTACT_ATTRIBS,{}).empty?)
	 	expected.should be(true)
	end

	it "should update an existing contact" do
		contact = add_new_user(@account,{})
    test_email = Faker::Internet.email
    test_phone_no = Faker::PhoneNumber.phone_number
    put :update, {:id => contact.id, :user => { :email => test_email, 
                                                :job_title => "Developer",
                                                :phone => test_phone_no,
                                                :time_zone => contact.time_zone, 
                                                :language => contact.language },:format => 'json'}
	 	response.status.should eql(200)
	end

	it "should delete an existing contact" do
		contact = add_new_user(@account,{})
		delete :destroy, {:id => contact.id, :format => 'json'}
		response.status.should be_eql(200)		
	end

	it "should fetch contacts filtered by email" do
		contact = add_new_user(@account,{})
	 	check_email  = contact.email
	 	get :index, {:query=>"email is #{check_email}", :state=>:all, :format => 'json'}
	 	result = parse_json(response)
	 	expected = (response.status == 200) && (compare(result.first["user"].keys,APIHelper::CONTACT_ATTRIBS,{}).empty?)
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
	 	get :index, {:query=>"phone is #{check_phone}", :state=>:all, :format => 'json'}
	 	result = parse_json(response)
	 	expected = (response.status == 200) && (compare(result.first["user"].keys,APIHelper::CONTACT_ATTRIBS,{}).empty?)
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
	 	get :index, {:query=>"mobile is #{check_mobile}", :state=>:all, :format => 'json'}
	 	result = parse_json(response)
	 	expected = (response.status == 200) && (compare(result.first["user"].keys,APIHelper::CONTACT_ATTRIBS,{}).empty?)
	 	expected.should be(true)
	end

  it "should fetch contacts filtered by company id" do
    new_company = Factory.build(:customer, :name => Faker::Name.name)
    new_company.save
    contact = Factory.build(:user, :account => @account,
                                    :name => Faker::Name.name, 
                                    :email => Faker::Internet.email,
                                    :mobile => 9876543210,
                                    :time_zone => "Chennai", 
                                    :delta => 1, 
                                    :language => "en",
                                    :customer_id => new_company.id)
    contact.save(false)
    check_id  = new_company.id
    get :index, {:query=>"customer_id is #{check_id}", :state=>:all, :format => 'json'}
    result = parse_json(response)
    expected = (response.status =~ /200 OK/) && (compare(result.first["user"].keys,APIHelper::CONTACT_ATTRIBS,{}).empty?)
    expected.should be(true)
  end

  

end