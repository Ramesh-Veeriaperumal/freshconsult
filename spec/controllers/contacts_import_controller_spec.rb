require 'spec_helper'

describe CustomersImportController do
	setup :activate_authlogic
	self.use_transactional_fixtures = false

	before(:all) do
		custom_field_params.each do |field| # to create contact custom fields
			params = cf_params(field)
			create_contact_field params  
		end
	end

	before(:each) do
		login_admin
		Aws::S3::Client.any_instance.stubs(:delete_object).returns(true)
	end

	after(:all) do
		destroy_custom_fields
		Aws::S3::Client.any_instance.unstub(:delete_object)
	end

	it "should open import csv page" do
		get :csv, :type => "contact"
		response.should be_success
		response.should render_template "customers_import/csv"
		response.body.should =~ /Import Contacts from CSV/
	end

	it "should accept file and display fields for mapping" do
		file = Rack::Test::UploadedFile.new('spec/fixtures/customers_import/contact.csv', 'csv')
		class << file
			attr_reader :tempfile
		end
		post :map_fields, { :type => "contact", :file => file }
		response.should render_template "customers_import/map_fields"
		response.body.should =~ /Map fields from your CSV with contact fields./
		assigns["rows"].count.should be_eql(2)
		assigns["fields"].should_not be_nil
		assigns["headers"].should_not be_nil
		@account.contact_form.fields.map { |fd| response.body.should =~ /#{fd.label}/}
	end

	it "should accept only csv file format" do
		file = Rack::Test::UploadedFile.new('spec/fixtures/files/image4kb.png', 'image/png')
		class << file
			attr_reader :tempfile
		end
		post :map_fields, { :type => "contact", :file => file}
		flash[:error].should =~ /The CSV file format is not supported. Please check the CSV file format!/
		response.should redirect_to "/imports/contact"
	end

	# value of dropdown field should only be the choices present for that particular field.
	# If we encounter an already existing contact email during import, then the other details of the contact will be updated.
	# email and url should be in correct format. Ex: sample@freshdesk.com and http://freshdesk.com/ respectively
	# checkbox accepts 'yes' or 'no'. Any other value encountered during the import will be considered as 'no'.
	it "should validate the field values" do
		file = Rack::Test::UploadedFile.new('spec/fixtures/customers_import/contact.csv', 'csv')
		class << file
			attr_reader :tempfile
		end
		Resque.inline = true
		post :map_fields, { :type => "contact", :file => file}

		post :create, { :type => "contact",
						:fields=>{
							"name"=>"0", "job_title"=>"2", "email"=>"1", "phone"=>"4","mobile"=>"", "twitter_id"=>"6", "company_name"=>"3", 
							"client_manager"=>"", "address"=>"7", "time_zone"=>"", "language"=>"", "tag_names"=>"9","description"=>"",
							
							"cf_date" =>"2","cf_category"=>"0", "cf_linetext"=>"", "cf_agt_count"=>"", "cf_file_url"=>"8", "cf_show_all_ticket"=>"2",
							 "cf_fax"=>"5", "cf_testimony"=>"7"}
						}
		Resque.inline = false
		@account.reload
		user = @account.users.find_by_email("karley_yost@example.net")
		user.should_not be_nil
		user.cf_testimony.should_not be_nil
		user.cf_testimony.should eql("79859 Queenie Island")
		user.cf_show_all_ticket.should eql(false)
		user.cf_category.should eql("Freshman")
		user.cf_file_url.should eql("http://blog.freshdesk.com/")

		@account.users.find_by_email("vallie@example.net").should be_nil
		@account.users.find_by_email("liliana.cremin@example.net").should be_nil
		@account.users.find_by_email("ayla@example.net").should be_nil
		@account.users.find_by_email("lola_hills@example.net").should be_nil

		user = @account.users.find_by_email("annamae_okuneva@example.org")
		user.should_not be_nil
		user.cf_category.should be_nil
		user.cf_file_url.should be_nil
		user.company_name.should eql("Hahn-Schuppe")
	end

	it "should create or update the imported contacts" do
		file = Rack::Test::UploadedFile.new('spec/fixtures/customers_import/contact.csv', 'csv')
		class << file
			attr_reader :tempfile
		end
		Resque.inline = true
		post :map_fields, { :type => "contact", :file => file}

		post :create, { :type => "contact",
						:fields=>{
							"name"=>"0", "job_title"=>"2", "email"=>"1", "phone"=>"4", "mobile"=>"", "twitter_id"=>"6", 
							"company_name"=>"3", "client_manager"=>"", "address"=>"7", "time_zone"=>"", "language"=>"", 
							"tag_names"=>"9","description"=>"",

							"cf_date" =>"2","cf_category"=>"11", "cf_linetext"=>"", "cf_agt_count"=>"", "cf_file_url"=>"", 
							"cf_show_all_ticket"=>"10", "cf_fax"=>"5", "cf_testimony"=>"8"}
						}
		Resque.inline = false
		@account.reload
		user = @account.users.find_by_email("karley_yost@example.net")
		user.should_not be_nil
		user.cf_date.should be_nil # value should be in date format(ex. Feb 23, 2015)
		user.cf_fax.should_not be_nil
		user.cf_testimony.should_not be_nil
		user.cf_testimony.should eql("http://blog.freshdesk.com/")
		user.cf_show_all_ticket.should eql(true)
		user.cf_category.should eql("First")

		user = @account.users.find_by_email("liliana.cremin@example.net")
		user.should_not be_nil
		user.cf_date.should be_nil
		user.cf_fax.should be_nil
		user.cf_testimony.should_not be_nil
		user.cf_testimony.should eql("Voluptates ad tempore aperiam dolor similique")
		user.cf_show_all_ticket.should eql(true)
		user.cf_category.should eql("Second")

		user = @account.users.find_by_email("vallie@example.net")
		user.should_not be_nil
		user.cf_date.should be_nil
		user.cf_fax.should_not be_nil
		user.cf_testimony.should_not be_nil
		user.cf_testimony.should eql("Illo eos neque nobis")
		user.cf_show_all_ticket.should eql(false)
		user.cf_category.should eql("Tenth")

		@account.users.find_by_email("samara@example.net").should be_nil
		@account.users.find_by_email("improper_invalidemail").should be_nil
	end
end