require 'spec_helper'

#Test cases for json api calls to contacts.
RSpec.describe ContactsController do
	self.use_transactional_fixtures = false

	context "For Contacts without custom fields" do
		before(:each) do
			request.host = @account.full_domain
			http_login(@agent)
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
			post :create, @params.merge!(:format => 'xml'), :content_type => 'application/xml'
			@account.companies.find_by_name(company_name).should be_an_instance_of(Customer)
			result = parse_xml(response)
			expected = (response.status == 201) && (compare(result["user"].keys,APIHelper::CONTACT_ATTRIBS,{}).empty?)
			expected.should be(true)
		end

		it "should create a contact" do # with new company parameters(customer deprecation)
			fake_a_contact
			@params[:user].merge!(:company_name => @new_company.name)
			post :create, @params.merge!(:format => 'xml'), :content_type => 'application/xml'
			result = parse_xml(response)
			expected = (response.status == 201) && (compare(result["user"].keys,APIHelper::CONTACT_ATTRIBS,{}).empty?)
			expected.should be(true)
		end

		it "should create a contact" do # To check normalize_params prioritization
			test_email = Faker::Internet.email
			company = FactoryGirl.build(:company)
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
			expected = (response.status == 201) && (compare(result["user"].keys,APIHelper::CONTACT_ATTRIBS,{}).empty?)
			expected.should be(true)
		end

		it "should show an existing contact" do
			contact = add_new_user(@account,{})
			get :show, {:id => contact.id, :format => 'xml'}
			result = parse_xml(response)
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
														:customer => @new_company.name },
											 :format => 'xml'}
			response.status.should eql(200)
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
			response.status.should eql(200)
			@account.companies.find_by_name(company_name).should be_an_instance_of(Customer)
		end

		it "should delete an existing contact" do
			contact = add_new_user(@account,{})
			delete :destroy, {:id => contact.id, :format => 'xml'}
			response.status.should be_eql(200)		
		end

		it "should fetch contacts filtered by email" do
			contact = add_new_user(@account,{})
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
			contact = FactoryGirl.build(:user, :account => @account,
											:name => Faker::Name.name, 
											:email => Faker::Internet.email,
											:phone => "42345678",
											:time_zone => "Chennai", 
											:delta => 1, 
											:language => "en")
			contact.save
			check_phone  = contact.phone
			get :index, {:query=>"phone is #{check_phone}", :state=>:all, :format => 'xml'}
			result = parse_xml(response)
			expected = (response.status == 200) && (compare(result["users"].first.keys,APIHelper::CONTACT_ATTRIBS,{}).empty?)
			expected.should be(true)
		end

		it "should fetch contacts filtered by mobile" do
			# This needs to be addressed. change filter expresssion in api_helper_methods
			contact = FactoryGirl.build(:user, :account => @account,
											:name => Faker::Name.name, 
											:email => Faker::Internet.email,
											:mobile => "9876543210",
											:time_zone => "Chennai", 
											:delta => 1, 
											:language => "en")
			contact.save
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
											:mobile => "9876543210",
											:time_zone => "Chennai", 
											:delta => 1, 
											:language => "en",
											:customer_id => new_company.id)
			contact.save
			check_id  = new_company.id
			get :index, {:query=>"customer_id is #{check_id}", :state=>:all, :format => 'xml'}
			result = parse_xml(response)
			expected = (response.status == 200) && (compare(result["users"].first.keys,APIHelper::CONTACT_ATTRIBS,{}).empty?)
			expected.should be(true)
		end

		it "should make user as agent" do
			contact = add_new_user(@account,{})
			put :make_agent, {:id => contact.id,:format => 'xml'}
			result = parse_xml(response)
			expected = (response.status == 200) && (compare(result["agent"].keys,APIHelper::AGENT_ATTRIBS,{}).empty?) && 
                (compare(result["agent"]["user"].keys,APIHelper::USER_ATTRIBS,{}).empty?)
            expected.should be(true)
		end
	end

	context "For Contacts with custom fields" do

		before(:all) do
			@user = FactoryGirl.build(:user, :account => @acc, :phone => Faker::PhoneNumber.phone_number, :email => Faker::Internet.email,
											:user_role => 3, :active => true)
			@user.save
			@custom_field = []
			custom_field_params.each do |field|
				@custom_field << "cf_#{field[:label].strip.gsub(/\s/, '_').gsub(/\W/, '').gsub(/[^ _0-9a-zA-Z]+/,"").downcase}".squeeze("_")
				params = cf_params(field)
				create_contact_field params 
			end
			@text = Faker::Lorem.words(4).join(" ")
		end

		before(:each) do
			request.host = @account.full_domain
			http_login(@agent)
		end

		after(:all) do
			@user.destroy
			destroy_custom_fields
		end

		it "should create a new contact with all custom fields" do
			test_email = Faker::Internet.email
			text = Faker::Lorem.words(4).join(" ")
			url = Faker::Internet.url
			post :create, :user => {:name => Faker::Name.name,
									:custom_field => contact_params({:linetext => text, :testimony => Faker::Lorem.paragraphs, :all_ticket => "false",
														:agt_count => "34", :fax => Faker::PhoneNumber.phone_number, :url => url, :date => date_time,
														:category => "Tenth", :text_regex_vdt => "Helpdesk Software"}),
									:email => test_email, 
									:time_zone => "Chennai", 
									:language => "en" 
									},
						  :format => 'xml'

			result = parse_xml(response)
			expected = (response.status == 201
        ) && (compare(result["user"].keys,APIHelper::CONTACT_ATTRIBS,{}).empty?) &&
							result["user"]["custom_field"].keys.sort == @custom_field.sort
			expected.should be(true)

			new_user = @account.user_emails.user_for_email(test_email)
			new_user.should be_an_instance_of(User)
			new_user.flexifield_without_safe_access.should_not be_nil
			new_user.send("cf_linetext").should eql(text)
			new_user.send("cf_category").should eql "Tenth"
			new_user.send("cf_agt_count").should eql(34)
			new_user.send("cf_show_all_ticket").should be false
			new_user.send("cf_file_url").should eql(url)
		end

		it "should create a new contact with few custom fields" do
			test_email = Faker::Internet.email
			text = Faker::Lorem.words(4).join(" ")
			url = Faker::Internet.url
			custom_field = {"cf_linetext" => text, "cf_show_all_ticket" => "true", 
							"cf_file_url" => url, "cf_category" => "First"}
			post :create, :user => {:name => Faker::Name.name,
									:custom_field => custom_field,
									:email => test_email, 
									:time_zone => "Chennai", 
									:language => "en" 
									},
						  :format => 'xml'

			result = parse_xml(response)
			expected = (response.status == 201) && (compare(result["user"].keys,APIHelper::CONTACT_ATTRIBS,{}).empty?) &&
							result["user"]["custom_field"].keys.sort == custom_field.map {|k,v| k.to_s}.sort
			expected.should be(true)

			new_user = @account.user_emails.user_for_email(test_email)
			new_user.should be_an_instance_of(User)
			new_user.flexifield_without_safe_access.should_not be_nil
			new_user.send("cf_linetext").should eql(text)
			new_user.send("cf_show_all_ticket").should be true
			new_user.send("cf_file_url").should eql(url)
			new_user.send("cf_agt_count").should be_nil
			new_user.send("cf_testimony").should be_nil
		end

		it "should update a contact with custom fields" do
			@user.flexifield_without_safe_access.should be_nil
			put :update,{:id => @user.id, 
						 :user=>{:name => Faker::Name.name,
								:custom_field => contact_params({:linetext => "updated text", :testimony => @text, 
								:all_ticket => "true", :agt_count => "7", :category => "First"}),
								:email => @user.email, 
								:job_title => "QA", 
								:time_zone => "Chennai", 
								:language => "en" 
								},
						 :format => 'xml'
						}
			user = @account.users.find(@user.id)
			user.job_title.should eql "QA"
			user.flexifield_without_safe_access.should_not be_nil
			user.send("cf_testimony").should eql(@text)
			user.send("cf_category").should eql "First"
			user.send("cf_agt_count").should eql(7)
			user.send("cf_show_all_ticket").should be true
			user.send("cf_file_url").should be_nil
			user.send("cf_linetext").should eql("updated text")
		end

		it "should not reset the existing custom_field values when custom params are not send while updating" do
			text = Faker::Lorem.words(4).join(" ")
			name = Faker::Name.name
			user = @account.users.find(@user.id)
			put :update,{:id => user.id, 
						 :user=>{:name => name,
								:email => user.email, 
								:job_title => "Sales Manager", 
								:time_zone => "Moscow", 
								:language => "en" 
								},
						 :format => 'xml'
						}
			user = @account.users.find(@user.id)
			user.job_title.should eql "Sales Manager"
			user.name.should eql(name)
			user.time_zone.should eql "Moscow"

			user.flexifield_without_safe_access.should_not be_nil
			user.send("cf_testimony").should eql(@text)
			user.send("cf_category").should eql "First"
			user.send("cf_agt_count").should eql(7)
			user.send("cf_show_all_ticket").should be true
			user.send("cf_file_url").should be_nil
			user.send("cf_linetext").should eql("updated text")
		end

		it "should update a contact with custom fields with null values" do
			text = Faker::Lorem.words(4).join(" ")
			name = Faker::Name.name
			user = @account.users.find(@user.id)
			user.flexifield_without_safe_access.should_not be_nil
			put :update,{:id => user.id, 
						 :user=>{:name => name,
								:custom_field => contact_params,
								:email => user.email, 
								:job_title => "Consultant", 
								:time_zone => "Chennai", 
								:language => "en" 
								},
						 :format => 'xml'
						}
			user = @account.users.find(@user.id)
			user.job_title.should eql "Consultant"

			# if account contains contact_custom_fields, ContactfieldData will be build and saved even though custom_field values are null
			# Only if the account doesn't have custom_fields, ContactfieldData will not build.
			user.flexifield_without_safe_access.should_not be_nil
			user.name.should eql(name)
		end
	end
end