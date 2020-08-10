require 'spec_helper'

describe CustomersImportController do
	setup :activate_authlogic
	self.use_transactional_fixtures = false

	before(:all) do
		custom_field_params.each do |field| # to create company custom fields
			params = company_params(field)
			create_company_field params  
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
		get :csv, :type => "company"
		response.should be_success
		response.should render_template "customers_import/csv"
		response.body.should =~ /Import Companies from CSV/
	end

	it "should accept file and display fields for mapping" do
		file = Rack::Test::UploadedFile.new('spec/fixtures/customers_import/company.csv', 'csv')
		class << file
			attr_reader :tempfile
		end
		post :map_fields, { :type => "company", :file => file}
		response.should render_template "customers_import/map_fields"
		response.body.should =~ /Map fields from your CSV with company fields./
		assigns["rows"].count.should be_eql(2)
		assigns["fields"].should_not be_nil
		assigns["headers"].should_not be_nil
		@account.company_form.fields.map { |fd| response.body.should =~ /#{fd.label}/}
	end

	it "should accept only csv file format" do
		file = Rack::Test::UploadedFile.new('spec/fixtures/files/image4kb.png', 'image/png')
		class << file
			attr_reader :tempfile
		end
		post :map_fields, { :type => "company", :file => file}
		flash[:error].should =~ /The CSV file format is not supported. Please check the CSV file format!/
		response.should redirect_to "/imports/company"
	end

	# value of dropdown field should only be the choices present for that particular field.
	# If we encounter an already existing company name during import, then the other details of the company will be updated.
	# url should be in correct format. Ex: http://freshdesk.com/ respectively
	# checkbox accepts 'yes' or 'no'. Any other value encountered during the import will be considered as 'no'.

	it "should validate the field values" do
		file = Rack::Test::UploadedFile.new('spec/fixtures/customers_import/company.csv', 'csv')
		class << file
			attr_reader :tempfile
		end
		Resque.inline = true
		post :map_fields, { :type => "company", :file => file}

		post :create, { :type => "company",
						:fields=>{
							"name"=>"0", "note"=>"1", "domains"=>"2", "description"=>"",
							
							"cf_date" =>"7","cf_category"=>"5", "cf_linetext"=>"1", "cf_agt_count"=>"6", "cf_file_url"=>"4", 
							"cf_show_all_ticket"=>"3","cf_fax"=>"8", "cf_testimony"=>""}
						}
		Resque.inline = false
		@account.reload
		company = @account.companies.find_by_name("Flashpoint")
		company.should_not be_nil
		company.cf_testimony.should be_nil
		company.cf_linetext.should_not be_nil
		company.cf_show_all_ticket.should eql(false)
		company.cf_category.should eql("Freshman")
		company.cf_date.should_not be_nil
		company.cf_fax.should eql("4-(264)811-2708")
		company.cf_file_url.should eql("https://wsj.com/turpis/eget")

		company = @account.companies.find_by_name("Shuffledrive")
		company.should_not be_nil
		company.cf_category.should eql("First")
		company.cf_file_url.should eql("http://marketwatch.com")
		company.cf_fax.should eql("4-(631)657-2379")
		company.cf_agt_count.should eql(31)

		company = @account.companies.find_by_name("Zooxo")
		company.should_not be_nil

		company.cf_linetext.should_not eql("Integer non velit. Donec diam neque vestibulum")
		company.cf_linetext.should eql("Proin at turpis a pede posuere nonummy. ")
		company.cf_show_all_ticket.should eql(true)

		company.cf_category.should_not eql("Tenth")
		company.cf_category.should eql("Third")

		company.cf_date.should be_nil
		company.cf_fax.should_not eql("5-(046)401-7891")
		company.cf_fax.should eql("0-(170)051-9262")
		company.cf_file_url.should eql("https://illinois.edu/cum/sociis.json")

		@account.companies.find_by_name("Brainsphere").should be_nil
		@account.companies.find_by_name("Realfire").should be_nil
		@account.companies.find_by_name("Quamba").should be_nil
		@account.companies.find_by_name("Twitterbridge").should be_nil
	end

	it "should create or update the imported companies" do
		file = Rack::Test::UploadedFile.new('spec/fixtures/customers_import/company.csv', 'csv')
		class << file
			attr_reader :tempfile
		end
		Resque.inline = true
		post :map_fields, { :type => "company", :file => file}

		post :create, { :type => "company",
						:fields=>{
							"name"=>"0", "note"=>"1", "domains"=>"2", "description"=>"",

							"cf_date" =>"7","cf_category"=>"", "cf_linetext"=>"", "cf_agt_count"=>"6", "cf_file_url"=>"", 
							"cf_show_all_ticket"=>"3","cf_fax"=>"9", "cf_testimony"=>"1"}
						}
		Resque.inline = false
		@account.reload
		@account.companies.find_by_name("Brainsphere").should_not be_nil
		@account.companies.find_by_name("Realfire").should_not be_nil
		@account.companies.find_by_name("Quamba").should_not be_nil
		@account.companies.find_by_name("Twitterbridge").should_not be_nil

		company = @account.companies.find_by_name("Flashpoint")
		company.cf_category.should eql("Freshman")
		company.cf_fax.should be_nil
		company.cf_file_url.should eql("https://wsj.com/turpis/eget")

		company = @account.companies.find_by_name("Shuffledrive")
		company.cf_file_url.should eql("http://marketwatch.com")
		company.cf_fax.should be_nil
		company.cf_agt_count.should eql(31)
	end
end