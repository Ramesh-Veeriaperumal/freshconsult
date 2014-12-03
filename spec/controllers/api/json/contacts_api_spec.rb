require 'spec_helper'

#Test cases for json api calls to contacts.
RSpec.describe ContactsController do
	self.use_transactional_fixtures = false

	context "For Contacts without custom fields" do

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
			response.status.should be_eql(200)
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
	    	contact.save
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
			contact.save
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
	    contact.save
	    check_id  = new_company.id
	    get :index, {:query=>"customer_id is #{check_id}", :state=>:all, :format => 'json'}
	    result = parse_json(response)
	    expected = (response.status == 200) && (compare(result.first["user"].keys,APIHelper::CONTACT_ATTRIBS,{}).empty?)
	    expected.should be(true)
	  end

	  it "should make user as agent" do
	    contact = add_new_user(@account,{})
	    put :make_agent, {:id => contact.id,:format => 'json'}
	    response.status.should eql(200)
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
			clear_json
		end

		after(:all) do
			Resque.inline = true
			@user.destroy
			custom_field_params.each { |params| 
				@account.contact_form.contact_fields.find_by_name("cf_#{params[:label].strip.gsub(/\s/, '_').gsub(/\W/, '').gsub(/[^ _0-9a-zA-Z]+/,"").downcase}".squeeze("_")).delete_field }
			Resque.inline = false
		end

		it "should create a new contact with custom fields" do
			test_email = Faker::Internet.email
			text = Faker::Lorem.words(4).join(" ")
			url = Faker::Internet.url
			avatar_file = Rack::Test::UploadedFile.new('spec/fixtures/files/image33kb.jpg', 'image/jpg')
			post :create, :user => {:name => Faker::Name.name,
									:custom_field => contact_params({:linetext => text, :testimony => Faker::Lorem.paragraphs, :all_ticket => "false",
														:agt_count => "34", :fax => Faker::PhoneNumber.phone_number, :url => url, :date => date_time,
														:category => "Tenth"}),
									:email => test_email, 
									:time_zone => "Chennai", 
									:language => "en" 
									},
						  :format => 'json'

			result = parse_json(response)
			expected = (response.status == 200) && (compare(result["user"].keys,APIHelper::CONTACT_ATTRIBS,{}).empty?) &&
							result["user"]["custom_field"].keys.all? { |attribute| @custom_field.include?(attribute)}
			expected.should be(true)

			new_user = @account.user_emails.user_for_email(test_email)
			new_user.should be_an_instance_of(User)
			new_user.flexifield_without_safe_access.should_not be_nil
			new_user.send("cf_linetext").should eql(text)
			new_user.send("cf_category").should eql "Tenth"
			new_user.send("cf_agt_count").should eql(34)
			new_user.send("cf_show_all_ticket").should be_false
			new_user.send("cf_file_url").should eql(url)
		end

		it "should create a new contact with custom fields value as null" do
			test_email = Faker::Internet.email
			name = Faker::Name.name
			post :create, :user => {:name => name,
									:custom_field => contact_params,
									:email => test_email, 
									:job_title => "Developer", 
									:time_zone => "Chennai", 
									:language => "en" 
									},
						  :format => 'json'

			result = parse_json(response)
			expected = (response.status == 200) && (compare(result["user"].keys,APIHelper::CONTACT_ATTRIBS,{}).empty?) &&
							result["user"]["custom_field"].keys.all? { |attribute| @custom_field.include?(attribute)}
			expected.should be(true)

			new_user = @account.user_emails.user_for_email(test_email)
			new_user.should be_an_instance_of(User)
			new_user.name.should eql(name)
			new_user.job_title.should eql "Developer"
			new_user.flexifield_without_safe_access.should be_nil
		end

		it "should update a contact with custom fields" do
			@user.flexifield_without_safe_access.should be_nil
			avatar_file = Rack::Test::UploadedFile.new('spec/fixtures/files/image33kb.jpg', 'image/jpg')
			put :update,{:id => @user.id, 
						 :user=>{:avatar_attributes => {:content => avatar_file},
								:name => Faker::Name.name,
								:custom_field => contact_params({:linetext => "updated text", :testimony => @text, 
								:all_ticket => "true", :agt_count => "7", :category => "First"}),
								:email => @user.email, 
								:job_title => "QA", 
								:time_zone => "Chennai", 
								:language => "en" 
								},
						 :format => 'json'
						}
			user = @account.users.find(@user.id)
			user.job_title.should eql "QA"
			user.flexifield_without_safe_access.should_not be_nil
			user.send("cf_testimony").should eql(@text)
			user.send("cf_category").should eql "First"
			user.send("cf_agt_count").should eql(7)
			user.send("cf_show_all_ticket").should be_true
			user.send("cf_file_url").should be_nil
			user.send("cf_linetext").should eql("updated text")
			user.avatar.should_not be_nil
			user.avatar.content_file_name.should eql "image33kb.jpg"
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
						 :format => 'json'
						}
			user = @account.users.find(@user.id)
			user.job_title.should eql "Sales Manager"
			user.name.should eql(name)
			user.time_zone.should eql "Moscow"

			user.flexifield_without_safe_access.should_not be_nil
			user.send("cf_testimony").should eql(@text)
			user.send("cf_category").should eql "First"
			user.send("cf_agt_count").should eql(7)
			user.send("cf_show_all_ticket").should be_true
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
						 :format => 'json'
						}
			user = @account.users.find(@user.id)
			user.job_title.should eql "Consultant"
			user.flexifield_without_safe_access.should be_nil
			user.name.should eql(name)
		end
	end
end