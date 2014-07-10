require 'spec_helper'

#Test cases for json api calls to contacts.
describe ContactsController do
  self.use_transactional_fixtures = false
  include APIAuthHelper


  before(:each) do
    request.host = @account.full_domain
    http_login(@agent)
  end

	it "should create a contact" do 
		fake_a_contact
		post :create, @params.merge!(:format => 'xml'), :content_type => 'application/xml'
		#api impl gives out 200 status, change this when its fixed to return '201 created'
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

	it "should update an existing contact" do
		contact = add_new_user(@account,{})
    test_email = Faker::Internet.email
    test_phone_no = Faker::PhoneNumber.phone_number
    put :update, {:id => contact.id, :user => { :email => test_email, 
                                                :job_title => "Developer",
                                                :phone => test_phone_no,
                                                :time_zone => contact.time_zone, 
                                                :language => contact.language },:format => 'xml'}
	 	response.status.should eql("200 OK")
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
		contact = Factory.build(:user, :account => @account,
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
		contact = Factory.build(:user, :account => @account,
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

end