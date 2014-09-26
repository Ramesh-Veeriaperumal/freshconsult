require 'spec_helper'

#include ContactImportHelper


describe Workers::Import::ContactsImportWorker do 

	before(:all) do		
		@sample_contact = Factory.build(:user, :account => @acc, :phone => "23423423434", :email => "samara@example.net", :user_role => 3)
		@sample_contact.save(false)
		@contact_import_params = YAML.load(File.read("spec/fixtures/contacts_import/contact_import.yml"))
		Resque.inline = true
		Workers::Import::ContactsImportWorker.new(@contact_import_params).perform
		Resque.inline = false
	end

	it "should create new contacts from the contacts imported" do 
		@account.users.find_by_email("karley_yost@example.net").should_not be_nil
	end

	it "should update contacts when the same email name or twitter id is used" do
		old_name = @sample_contact.name
		new_name = @account.users.find_by_email("samara@example.net").name
		(new_name != old_name).should be_true
	end

	it "should add company on importing" do
		@sample_contact.company.should be_nil
		@account.users.find_by_email("samara@example.net").company.should_not be_nil
	end

	it "should add job title on importing" do
		@sample_contact.job_title.should be_nil
		@account.users.find_by_email("samara@example.net").job_title.should_not be_nil
	end

	it "should add work phone and mobile phone numbers" do
		@account.users.find_by_email("ayla@example.net").phone.should_not be_nil
		@account.users.find_by_email("ayla@example.net").mobile.should_not be_nil
	end

	it "should add tags to the user" do
		@account.users.find_by_email("ayla@example.net").tags.should_not be_nil
	end

	it "should add background information about the user" do
		@account.users.find_by_email("ayla@example.net").description.should_not be_nil
	end

end