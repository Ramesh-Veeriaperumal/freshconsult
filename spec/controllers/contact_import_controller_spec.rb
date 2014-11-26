require 'spec_helper'

describe ContactImportController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

	before(:each) do
		login_admin
		AWS::S3::S3Object.any_instance.stubs(:delete).returns(true)
	end

	it "should open import csv page" do
		get :csv
		response.should render_template "contact_import/csv"
		response.body.should =~ /Import Customers from CSV/
	end

	it "should accept files and create contacts" do
		Resque.inline = true
		file = Rack::Test::UploadedFile.new('spec/fixtures/contacts_import/contact.csv', 'csv')
		class << file
			attr_reader :tempfile
		end
		post :create, { :commit => "import", :file => file }
		post :create, {"fields"=>{"0"=>"0", "1"=>"2", "2"=>"1", "3"=>"4", "4"=>"", "5"=>"5", "6"=>"3", "7"=>"", "8"=>"", "9"=>"", "10"=>"", "11"=>"", "12"=>""}}
		Resque.inline = false
		@account.users.find_by_email("karley_yost@example.net").should_not be_nil
	end

end