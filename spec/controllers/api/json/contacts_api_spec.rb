require 'spec_helper'

#Test cases for json api calls to contacts.
RSpec.describe ContactsController do
	self.use_transactional_fixtures = false

	before(:each) do
		request.host = @account.full_domain
		http_login(@agent)
		clear_json
	end

	before(:all) do
		@new_company = FactoryGirl.build(:company)
		@new_company.save
	end

	after(:all) do
		@new_company.destroy
	end

	it "should create a contact" do # with old company parameters(customer deprecation)
		fake_a_contact
		company_name = Faker::Name.name
		@params[:user].merge!(:customer => company_name)
		post :create, @params.merge!(:format => 'json'), :content_type => 'application/json'
	 	# result = parse_json(response)
		#api impl gives out 200 status, change this when its fixed to return '201 created'
	 	#also add helpdesk_agent attrib to json response to be in sync with xml
	 	#&& compare(result["user"],APIHelper::CONTACT_ATTRIBS,{})
		response.status.should be_eql(200)
		@account.companies.find_by_name(company_name).should be_an_instance_of(Customer)
	end

	it "should create a contact" do # with new company parameters(customer deprecation)
		fake_a_contact
		@params[:user].merge!(:company_name => @new_company.name)
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

	it "should update an existing contact" do # with old company parameters(customer deprecation)
		contact = add_new_user(@account,{})
		test_email = Faker::Internet.email
		test_phone_no = Faker::PhoneNumber.phone_number
		put :update, {:id => contact.id, :user => { :email => test_email, 
													:job_title => "Developer",
													:phone => test_phone_no,
													:time_zone => contact.time_zone, 
													:language => contact.language, 
													:customer => @new_company.name },:format => 'json'}
		response.status.should eql(200)
	end

	it "should update an existing contact" do # with old company parameters(customer deprecation)
		contact = add_new_user(@account,{})
		test_email = Faker::Internet.email
		test_phone_no = Faker::PhoneNumber.phone_number
		company_name = Faker::Name.name
		put :update, {:id => contact.id, :user => { :email => test_email, 
													:job_title => "Developer",
													:phone => test_phone_no,
													:time_zone => contact.time_zone, 
													:language => contact.language, 
													:company_name => company_name },:format => 'json'}
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
		contact = FactoryGirl.build(:user, :account => @account,
										:name => Faker::Name.name, 
										:email => Faker::Internet.email,
										:phone => 42345678,
										:time_zone => "Chennai", 
										:delta => 1, 
										:language => "en")
		contact.save(:validate => false)
		check_phone  = contact.phone
		get :index, {:query=>"phone is #{check_phone}", :state=>:all, :format => 'json'}
		result = parse_json(response)
		expected = (response.status == 200) && (compare(result.first["user"].keys,APIHelper::CONTACT_ATTRIBS,{}).empty?)
		expected.should be(true)
	end

	it "should fetch contacts filtered by mobile" do
		# This needs to be addressed. change filter expresssion in api_helper_methods
		contact = FactoryGirl.build(:user, :account => @account,
										:name => Faker::Name.name, 
										:email => Faker::Internet.email,
										:mobile => 9876543210,
										:time_zone => "Chennai", 
										:delta => 1, 
										:language => "en")
		contact.save(:validate => false)
		check_mobile  = contact.mobile
		get :index, {:query=>"mobile is #{check_mobile}", :state=>:all, :format => 'json'}
		result = parse_json(response)
		expected = (response.status == 200) && (compare(result.first["user"].keys,APIHelper::CONTACT_ATTRIBS,{}).empty?)
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
    get :index, {:query=>"customer_id is #{check_id}", :state=>:all, :format => 'json'}
    result = parse_json(response)
    expected = (response.status == 200) && (compare(result.first["user"].keys,APIHelper::CONTACT_ATTRIBS,{}).empty?)
    expected.should be(true)
  end

  

end