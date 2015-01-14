require 'spec_helper'

describe Admin::ContactFieldsController do
	integrate_views
	setup :activate_authlogic
	self.use_transactional_fixtures = false

	before(:all) do
		@user = []
		5.times { @user << add_new_user(@account) }
		@cf_date = create_contact_field(cf_params({ :type=>"date", :field_type=>"custom_date", :label=>"Date"}))
		@field_name = "Testimony"
	end

	before(:each) do
		login_admin
		@default_contact_fields = []
		@account.contact_form.fields.map { |field| @default_contact_fields << field.as_json.values.first }
	end

	after(:all) do
		destroy_custom_fields
	end

	it "should go to the index page" do
		get 'index'
		response.should render_template "admin/contact_fields/index.html.erb"
		response.body.should =~ /Customizing your contact fields/
	end

	it "should go to the contact fields json" do
		get 'index', :format => "json"
		data_json = JSON.parse(response.body)
		(data_json[0]['contact_field']['label']).should eql "Full Name"
	end

	it "should go to the contact fields xml" do
		get 'index', :format => "xml"
		data_xml = Hash.from_trusted_xml(response.body)
		(data_xml['contact_fields'][0]['label']).should eql "Full Name"
	end

	it "should create a custom field" do
		put :update, :jsonData => 
			@default_contact_fields.push(
				cf_params({ :type=>"paragraph", :field_type=>"custom_paragraph", :label=> @field_name }).merge!(:action => "create"),
				cf_params({ :type=>"url", :field_type=>"custom_url", :label=>"File URL", :editable_in_signup => "true"}).merge!(:action => "create"),
				cf_params({ :type=>"number", :field_type=>"custom_number", :label=>"Number"}).merge!(:action => "create"),
				cf_params({ :type => "dropdown", :field_type => "custom_dropdown", :label => "Category",
							:custom_field_choices_attributes => [ 
											{"value"=>"First", "position"=>1, "_destroy"=>0, "name"=>"First"}, 
                                            {"value"=>"Second", "position"=>2, "_destroy"=>0, "name"=>"Second"}, 
                                            {"value"=>"Third", "position"=>3, "_destroy"=>0, "name"=>"Third"}, 
                                            {"value"=>"Tenth", "position"=>4, "_destroy"=>0, "name"=>"Tenth"}]}).merge!(:action => "create")
			).to_json

		cf_testimony = @account.contact_form.fields.find_by_name("cf_testimony")
		cf_testimony.should_not be_nil

		# creating a new contact with custom field "Testimony"
		text = Faker::Lorem.paragraph
		custom_flexifield({:user_id => @user[0].id, :testimony => text })
		user = @account.users.find(@user[0].id)
		user.send("cf_testimony").should eql(text)

		cf_file_url = @account.contact_form.fields.find_by_name("cf_file_url")
		cf_file_url.should_not be_nil
		cf_file_url.editable_in_signup.should be_true

		cf_number = @account.contact_form.fields.find_by_name("cf_number")
		cf_number.should_not be_nil

		parent_custom_field = @account.contact_form.fields.find_by_name("cf_category")
		parent_custom_field.custom_field_choices.count.should eql(4)
		parent_custom_field.custom_field_choices.first.value.should eql "First"
		parent_custom_field.custom_field_choices.last.value.should eql "Tenth"
	end

	it "should create a single_line_text field with regex validation" do
		regex_condn = {"regex"=>{"pattern" => "^.*(desk)$","modifier" => ""}}
		put :update, :jsonData => 
			@default_contact_fields.push(
				cf_params({ :type=>"text", :field_type=>"custom_text", :label=> "text_fd with validation", 
							:field_options => regex_condn }).merge!(:action => "create")).to_json
		cf_regex = @account.contact_form.fields.find_by_name("cf_text_fd_with_validation")
		cf_regex.should_not be_nil
		cf_regex.field_options.should eql(regex_condn)
	end

	it "should not create a custom field with same name" do
		put :update, :jsonData => 
			@default_contact_fields.push(
				cf_params({ :type=>"paragraph", :field_type=>"custom_paragraph", :label=> @field_name }).merge!(:action => "create")
			).to_json
		flash[:error].should =~ /Name has already been taken/
	end

	it "should edit a custom and default field" do
		cf_org = create_contact_field(cf_params({ :type=>"text", :field_type=>"custom_text", :label=> "Org details", :editable_in_signup => "true"}))
		cf_company = @account.contact_form.fields.find_by_name("company_name")
		regex_condn = {"regex"=>{"pattern" => "^FreSh","modifier" => "i"}}

		put :update, :jsonData => 
			@default_contact_fields.push(
				cf_update_params(cf_org,{:label=>"Organization Details", :visible_in_portal => "false", 
									:editable_in_portal=>"false", :type=>"text", :editable_in_signup => "false", 
									:field_options => regex_condn, :action=>"update"}),
																
				cf_update_params(cf_company,{:label_in_portal=>"Company Name",:label=>"Company", 
									:required_for_agent=>"true", :required_in_portal => "true", :type=>"text", :action=>"update"})
			).to_json
		
		cf_company.reload
		cf_company.label_in_portal.should_not eql "Company Name" # default field labels cant be edited.
		cf_company.required_in_portal.should be_true
		cf_company.required_for_agent.should be_true

		cf_org.reload
		cf_org.label.should eql "Organization Details"
		cf_org.visible_in_portal.should be_false
		cf_org.editable_in_portal.should be_false
		cf_org.required_in_portal.should be_false
		cf_org.editable_in_signup.should be_false
		cf_org.field_options.should eql(regex_condn)

		# creating a new contact with custom field "Testimony" and "Date"
		date = Time.zone.now.beginning_of_day
		text = Faker::Lorem.words(4).join(" ")
		custom_flexifield({:user_id => @user[1].id, :date => date, :testimony => text})
		user = @account.users.find(@user[1].id)
		user.send("cf_date").should_not be_nil
		user.send("cf_testimony").should eql(text)
	end

	# when Resque.inline = true, the corresponding field record will get deleted completely from contact_field table
	it "should delete custom fields" do 
		testimony = @account.contact_form.fields.find_by_name("cf_testimony").column_name
		date = @account.contact_form.fields.find_by_name("cf_date").column_name

		# creating a new contact with wrong def_id
		id = "9098787"
		custom_flexifield({ :user_id => @user[2].id, :def_id => id })
		@user[2].flexifield_without_safe_access.should be_an_instance_of(ContactFieldData)

		# creating a new contact with wrong account_id
		flexifield = custom_flexifield({ :user_id => @user[3].id, :account_id => id })
		flexifield.should be_true

		cf_testimony = @account.contact_form.fields.find_by_name("cf_#{@field_name}")

		Resque.inline = true
		put :update, :jsonData => @default_contact_fields.push(
				cf_update_params(@cf_date,{:type=>"date", :action=>"delete"}),
				cf_update_params(cf_testimony,{:type=>"paragraph", :action=>"delete"}) ).to_json
		
		@account.contact_form.fields.find_by_id(@cf_date.id).should be_nil

		@account.contact_form.fields.find_by_id(cf_testimony.id).should be_nil
		Resque.inline = false

		3.times do |x|
			if x != 2
				user = @account.users.find(@user["#{x}".to_i].id)
				user.flexifield_without_safe_access[:"#{testimony}"].should be_nil
				user.flexifield_without_safe_access[:"#{date}"].should be_nil
			else
				user = @account.users.find(@user["#{x}".to_i].id)
				user.flexifield_without_safe_access[:"#{testimony}"].should_not be_nil
				user.flexifield_without_safe_access[:"#{date}"].should_not be_nil
			end
		end
	end

	# when Resque.inline = false, the corresponding field record will not get deleted from contact_field table 
	#   but attribute :deleted in contact_field table turns to "true"
	it "should delete custom fields(Resque false)" do
		cf_org = @account.contact_form.fields.find_by_name("cf_org_details")
		put :update, :jsonData => @default_contact_fields.push(
				cf_update_params(cf_org,{:type=>"date", :action=>"delete"}) ).to_json
		cf_org.reload.deleted.should be_true
	end

	it "should not create a field with the same deleted field label when it is not hard deleted from table" do
		# when we try to create same field "org_details" which is not deleted from the table, creation process should throw an error...
		put :update, :jsonData => 
			@default_contact_fields.push(
				cf_params({ :type=>"text", :field_type=>"custom_text", :label=> "Org details" }).merge!(:action => "create")).to_json
		flash[:error].should =~ /Name has already been taken/
	end

	it "should not create custom_fields more than the available columns(boolean)" do
		contact_fields = @default_contact_fields
		11.times do |x|
			contact_fields.push(cf_params({ :type=>"checkbox", :field_type=>"custom_checkbox", :label=> "chkbox#{x}" }).merge!(:action => "create"))
		end
		put :update, :jsonData => contact_fields.to_json

		flash[:error].should =~ /You are not allowed to create more fields of this type./
		11.times do |x|
			if x < 10
				cf_checkbox = @account.contact_form.fields.find_by_name("cf_chkbox#{x}")
				cf_checkbox.should_not be_nil
			else
				@account.contact_form.fields.find_by_name("cf_chkbox#{x}").should be_nil
			end
		end
	end

		def cf_update_params contact_field, options = {}
			{
				:column_name => contact_field.id,
				:contact_form_id => @account.contact_form.id,
				:field_options => options[:field_options] || nil,  
				:field_type => contact_field.field_type, 
				:id=> contact_field.id, 
				:label=> options[:label] || contact_field.label, 
				:label_in_portal=> options[:label_in_portal] || contact_field.label_in_portal, 
				:name=> contact_field.name, 
				:position=> rand(1..21), 
				:required_for_agent=> options[:required_for_agent] || contact_field.required_for_agent,  
				:visible_in_portal=> options[:visible_in_portal] || contact_field.visible_in_portal, 
				:editable_in_portal => options[:editable_in_portal] || contact_field.editable_in_portal,
				:required_in_portal=> options[:required_in_portal] || contact_field.required_in_portal,
				:editable_in_signup=> options[:editable_in_signup] || contact_field.required_in_portal,
				:type=> options[:type], :action=> options[:action]
			}
		end

		def custom_flexifield options = {}
			testimony = @account.contact_form.fields.find_by_name("cf_testimony").column_name
			date = @account.contact_form.fields.find_by_name("cf_date").column_name
			contact_field_data = Factory.build(:contact_field_data, 
												:contact_form_id => options[:def_id] || @account.contact_form.id,
												:user_id => options[:user_id],
												:"#{date}" => options[:date] || date_time,
												:"#{testimony}" => options[:testimony] || Faker::Lorem.words(7).join(" "),
												:account_id => options[:account_id] || @account.id)
			contact_field_data.save
		end
end