require 'spec_helper'

#Test cases for json api calls to contacts.
describe ContactsController do
	self.use_transactional_fixtures = false
	include APIAuthHelper

	before(:each) do
		request.host = @account.full_domain
		http_login(@agent)
	end

	before(:all) do
		@new_company = Factory.build(:company)
		@new_company.save
	end

	after(:all) do
		@new_company.destroy
	end

	it "should create a contact" do # with old company parameters(customer deprecation)
		fake_a_contact
		company_name = Faker::Name.name
		@params[:user].merge!(:customer => company_name)
		post :create, @params.merge!(:format => 'xml'), :content_type => 'application/xml'
		@account.companies.find_by_name(company_name).should be_an_instance_of(Customer)
		result = parse_xml(response)
		expected = (response.status =~ /201 Created/) && (compare(result["user"].keys,APIHelper::CONTACT_ATTRIBS,{}).empty?)
		expected.should be(true)
	end

	it "should create a contact" do # with new company parameters(customer deprecation)
		fake_a_contact
		@params[:user].merge!(:company_name => @new_company.name)
		post :create, @params.merge!(:format => 'xml'), :content_type => 'application/xml'
		result = parse_xml(response)
		expected = (response.status =~ /201 Created/) && (compare(result["user"].keys,APIHelper::CONTACT_ATTRIBS,{}).empty?)
		expected.should be(true)
	end

	it "should create a contact" do # To check normalize_params prioritization
		test_email = Faker::Internet.email
		company = Factory.build(:company)
		company.save
		post :create, :user => {:name => Faker::Name.name, 
								:email => test_email , 
								:time_zone => "Chennai", 
								:language => "en", 
								:customer_id => @new_company.id, 
								:company_id => company.id },
					  :format => 'xml', :content_type => 'application/xml'
		new_contact = @account.user_emails.user_for_email(test_email)
		new_contact.should be_an_instance_of(User)
		new_contact.company_id.should eql company.id
		result = parse_xml(response)
		expected = (response.status =~ /201 Created/) && (compare(result["user"].keys,APIHelper::CONTACT_ATTRIBS,{}).empty?)
		expected.should be(true)
	end

	it "should show an existing contact" do
		contact = add_new_user(@account,{})
		get :show, {:id => contact.id, :format => 'xml'}
		result = parse_xml(response)
		expected = (response.status =~ /200 OK/) && (compare(result["user"].keys,APIHelper::CONTACT_ATTRIBS,{}).empty?)
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
													:customer => @new_company.name },
										 :format => 'xml'}
		response.status.should eql("200 OK")
	end

	it "should update an existing contact" do # with new company parameters(customer deprecation)
		contact = add_new_user(@account,{})
		test_email = Faker::Internet.email
		test_phone_no = Faker::PhoneNumber.phone_number
		company_name = Faker::Name.name
		put :update, {:id => contact.id, :user => { :email => test_email, 
													:job_title => "QA",
													:phone => test_phone_no,
													:time_zone => contact.time_zone, 
													:language => contact.language,
													:company_name => company_name},:format => 'xml'}
		response.status.should eql("200 OK")
		@account.companies.find_by_name(company_name).should be_an_instance_of(Customer)
	end

	it "should delete an existing contact" do
		contact = add_new_user(@account,{})
		delete :destroy, {:id => contact.id, :format => 'xml'}
		response.status.should be_eql('200 OK')		
	end

	it "should fetch contacts filtered by email" do
		contact = add_new_user(@account,{})
		check_email  = contact.email
		get :index, {:query=>"email is #{check_email}", :state=>:all, :format => 'xml'}
		result = parse_xml(response)
		expected = (response.status =~ /200 OK/) && (compare(result["users"].first.keys,APIHelper::CONTACT_ATTRIBS,{}).empty?)
		expected.should be(true)
	end

	it "should fetch contacts filtered by phone" do
		# phone/mobile filter now searches only valid numerics: 1231234
		# US numbers format is not searched 812.123.1232 or (802)-123-1232
		# Hence not using Faker for phonenumber generation.
		# This needs to be addressed. change filter expresssion in api_helper_methods
		contact = Factory.build( :user, :account => @account,
										:name => Faker::Name.name, 
										:email => Faker::Internet.email,
										:phone => 42345678,
										:time_zone => "Chennai", 
										:delta => 1, 
										:language => "en")
		contact.save(false)
		check_phone  = contact.phone
		get :index, {:query=>"phone is #{check_phone}", :state=>:all, :format => 'xml'}
		result = parse_xml(response)
		expected = (response.status =~ /200 OK/) && (compare(result["users"].first.keys,APIHelper::CONTACT_ATTRIBS,{}).empty?)
		expected.should be(true)
	end

	it "should fetch contacts filtered by mobile" do
		# This needs to be addressed. change filter expresssion in api_helper_methods
		contact = Factory.build( :user, :account => @account,
										:name => Faker::Name.name, 
										:email => Faker::Internet.email,
										:mobile => 9876543210,
										:time_zone => "Chennai", 
										:delta => 1, 
										:language => "en")
		contact.save(false)
		check_mobile  = contact.mobile
		get :index, {:query=>"mobile is #{check_mobile}", :state=>:all, :format => 'xml'}
		result = parse_xml(response)
		expected = (response.status =~ /200 OK/) && (compare(result["users"].first.keys,APIHelper::CONTACT_ATTRIBS,{}).empty?)
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
    get :index, {:query=>"customer_id is #{check_id}", :state=>:all, :format => 'xml'}
    result = parse_xml(response)
    expected = (response.status =~ /200 OK/) && (compare(result["users"].first.keys,APIHelper::CONTACT_ATTRIBS,{}).empty?)
    expected.should be(true)
  end

end