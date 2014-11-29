require 'spec_helper'

describe Support::ProfilesController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  context "For Profile without custom fields" do

    before(:all) do
      @user = add_new_user(@account, {:active => true})
    end

    before(:each) do
      log_in(@user)
    end

    after(:all) do
      @user.destroy
    end

    it "should update an existing contact" do
      get :edit, :id => @user.id
      response.should render_template :edit
      phone_no = Faker::PhoneNumber.phone_number
      put :update, :id => @user.id, :user => {:name => @user.name,
                                              :job_title => "Developer",
                                              :phone => phone_no,
                                              :time_zone => "Arizona",
                                              :language => "fr" }
      @user.reload
      @user.phone.should eql(phone_no)
      @user.time_zone.should eql("Arizona")
      @user.language.should eql("fr")
    end

    it "should add user avatar to existing user" do
      get :edit, :id => @user.id
      avatar_file = Rack::Test::UploadedFile.new('spec/fixtures/files/image33kb.jpg', 'image/jpg')
      put :update, :id => @user.id, :user => {:avatar_attributes => {:content => avatar_file},
                                              :name => @user.name,
                                              :job_title => @user.job_title,
                                              :phone => @user.phone,
                                              :time_zone => @user.time_zone,
                                              :language => @user.language }
      @user.reload
      @user.avatar.should_not be_nil 
      @user.avatar.content_file_name.should eql "image33kb.jpg"   
    end

    it "should update user avatar to existing user" do # User PROTECTED_ATTRIBUTES should not be updated, it should get cleanedup while updating...
      email = Faker::Internet.email
      get :edit, :id => @user.id
      avatar_file = Rack::Test::UploadedFile.new('spec/fixtures/files/image4kb.png','image/png')
      put :update, :id => @user.id, :user => {:avatar_attributes => {:content => avatar_file, :id => @user.avatar.id, :_destroy =>"0"},
                                              :name => @user.name,
                                              :email => email, # cleanuped param
                                              :job_title => @user.job_title,
                                              :phone => @user.phone,
                                              :time_zone => @user.time_zone,
                                              :company_name => "New company", # cleanuped param
                                              :language => @user.language }
      @user.reload
      @user.email.should_not eql(email)
      @user.customer_id.should_not eql "New company"
      @user.avatar.should_not be_nil
      @user.avatar.content_file_name.should eql "image4kb.png"    
    end

    it "should delete user avatar" do
      get :edit, :id => @user.id
      put :update, :id => @user.id, :user => {:avatar_attributes => {:id => @user.avatar.id, :_destroy =>"1"},
                                              :name => @user.name,
                                              :job_title => @user.job_title,
                                              :phone => @user.phone,
                                              :time_zone => @user.time_zone,
                                              :language => @user.language }
      @user.reload
      @user.avatar.should be_nil
    end
  end

  context "For Profile with custom fields" do

    before(:all) do
      custom_field_params.each do |field|
        params = cf_params(field)
        create_contact_field params  
      end
      @name = "Customer with custom_fields"
      @user = add_new_user(@account, {:active => true})
    end

    before(:each) do
      log_in(@user)
    end

    after(:all) do
      Resque.inline = true
      @user.destroy
      custom_field_params.each { |params| 
        @account.contact_form.contact_fields.find_by_name("cf_#{params[:label].strip.gsub(/\s/, '_').gsub(/\W/, '').gsub(/[^ _0-9a-zA-Z]+/,"").downcase}".squeeze("_")).delete_field }
      Resque.inline = false
    end

    it "should edit an existing contact with custom fields" do
      get :edit, :id => @user.id # Agt Count is a invisible field.
      custom_field_params.each { |field| field[:label_in_portal] != "Agt Count" ? response.body.should =~ /#{field[:label_in_portal]}/ : 
                                          response.body.should_not =~ /#{field[:label_in_portal]}/ }
    end

    it "should update an existing contact with custom fields" do
      get :edit, :id => @user.id
      avatar_file = Rack::Test::UploadedFile.new('spec/fixtures/files/image33kb.jpg', 'image/jpg')
      testimony = Faker::Lorem.paragraph
      put :update, :id => @user.id, 
                    :user => {:avatar_attributes => {:content => avatar_file},
                              :name => @name,
                              :custom_field => contact_params({:linetext => Faker::Lorem.words(4).join(" "), :testimony => testimony, 
                                                               :all_ticket => "true", :fax => Faker::PhoneNumber.phone_number, 
                                                               :date => date_time, :category => "First"}),
                              :job_title => @user.job_title,
                              :phone => @user.phone,
                              :time_zone => @user.time_zone,
                              :language => @user.language 
                              }
      user = @account.users.find(@user.id)
      user.name.should eql(@name)
      user.flexifield_without_safe_access.should_not be_nil
      user.send("cf_testimony").should eql(testimony)
      user.send("cf_category").should eql "First"
      user.send("cf_agt_count").should be_nil
      user.send("cf_file_url").should be_nil
      user.send("cf_show_all_ticket").should be_true
      user.avatar.should_not be_nil
      user.avatar.content_file_name.should eql "image33kb.jpg"
    end

    it "should not allow required fields to be null" do # Testimony is a mandatory field.
      avatar_file = Rack::Test::UploadedFile.new('spec/fixtures/files/image4kb.png','image/png')
      put :update,  :id => @user.id, 
                    :user => {:avatar_attributes => {:content => avatar_file, :id => @user.avatar.id, :_destroy =>"0"},
                              :name => Faker::Name.name,
                              :custom_field => contact_params({:linetext => "", :testimony => "", :all_ticket => "true", 
                                                               :fax => Faker::PhoneNumber.phone_number, :date => "", :category => "third"}),
                              :job_title => @user.job_title,
                              :phone => @user.phone,
                              :time_zone => @user.time_zone,
                              :language => @user.language 
                              }
      user = @account.users.find(@user.id)
      contact_field = @account.contact_form.contact_fields.find_by_name("cf_testimony")
      response.body.should =~ /prohibited this user from being saved/
      response.body.should =~ /#{contact_field.label} cannot be blank/
      user.send("cf_category").should_not eql "third"
      user.send("cf_date").should_not be_nil
      user.avatar.content_file_name.should_not eql "image4kb.png"
    end

    it "should not allow required fields to be null" do # when check box is a mandatory field, value of the field should be always true.
      user_name = Faker::Name.name
      fax = "7665456767"
      put :update,  :id => @user.id, 
                    :user => {:name => user_name,
                              :custom_field => contact_params({:linetext => Faker::Lorem.words(4), :testimony => Faker::Lorem.paragraph, 
                                                               :all_ticket => "false", :fax => fax, :date => "2014-04-17 10:58:45", 
                                                               :category => "Second"}),
                              :job_title => @user.job_title,
                              :phone => @user.phone,
                              :time_zone => @user.time_zone,
                              :language => @user.language 
                              }
      user = @account.users.find(@user.id)
      contact_field = @account.contact_form.contact_fields.find_by_name("cf_show_all_ticket")
      response.body.should =~ /prohibited this user from being saved/
      response.body.should =~ /#{contact_field.label} cannot be blank/
      user.send("cf_category").should_not eql "Second"
      user.send("cf_fax").should_not eql(fax)
      user.name.should_not eql(user_name)
      user.name.should eql(@name)
    end

    it "should not allow invisible field values" do # Agt Count is a invisible field.
      user_name = Faker::Name.name
      fax = "7665456767"
      testimony = Faker::Lorem.sentence(3)
      put :update,  :id => @user.id, 
                    :user => {:name => user_name,
                              :custom_field => contact_params({:linetext => Faker::Lorem.words(4).join(" "), :testimony => testimony, 
                                                               :all_ticket => "true", :fax => fax, :date => "2014-04-17 10:58:45", 
                                                               :agt_count => "34", :category => "Tenth"}),
                              :job_title => @user.job_title,
                              :phone => @user.phone,
                              :time_zone => @user.time_zone,
                              :language => @user.language 
                              }
      user = @account.users.find(@user.id)
      user.name.should eql(user_name)
      user.send("cf_agt_count").should be_nil
      user.send("cf_testimony").should eql(testimony)
      user.send("cf_fax").should eql(fax)
      user.send("cf_category").should eql "Tenth"
    end

    it "should not edit fields that are not allowed to edit_in_portal" do # File Url is a uneditable field.
      description = Faker::Lorem.paragraph
      url = Faker::Internet.url
      put :update,  :id => @user.id, 
                    :user => {:avatar_attributes => {:id => @user.avatar.id, :_destroy =>"1"},
                              :name => @user.name,
                              :custom_field => contact_params({:linetext => Faker::Lorem.words(2).join(" "), :testimony => description, 
                                                               :all_ticket => "true", :url => url}),
                              :job_title => @user.job_title,
                              :phone => @user.phone,
                              :time_zone => @user.time_zone,
                              :language => @user.language 
                              }
      user = @account.users.find(@user.id)
      user.send("cf_testimony").should eql(description)
      user.send("cf_file_url").should_not eql(url)
      user.send("cf_file_url").should be_nil
      user.send("cf_category").should be_nil
      user.avatar.should be_nil
    end

    # REGEX VALIDATION :
    # custom_field "Linetext with regex validation" should either contain "desk" or "service" as a field value 
    # if field_value doesn't contain either of these words, request should throw an error message as "invalid value"
    
    it "should update a contact" do # single line text with regex validation.
      text = Faker::Lorem.words(4).join(" ")
      name = Faker::Name.name
      @user.reload
      put :update, :id => @user.id,
                    :user => {:name => name,
                              :custom_field => contact_params({:linetext => text, :testimony => Faker::Lorem.paragraph, :all_ticket => "true", :date => date_time, 
                                                               :category => "Third", :text_regex_vdt => "customer service with Freshdesk"}),
                              :job_title => @user.job_title,
                              :phone => @user.phone,
                              :time_zone => @user.time_zone,
                              :language => @user.language 
                              }
      user = @account.users.find(@user.id)
      user.name.should eql(name)
      user.flexifield_without_safe_access.should_not be_nil
      user.send("cf_linetext").should eql(text)
      user.send("cf_category").should eql "Third"
      user.send("cf_show_all_ticket").should be_true
      user.send("cf_linetext_with_regex_validation").should eql "customer service with Freshdesk"
    end

    it "should not update a contact with invalid value in regex field" do
      text = Faker::Lorem.words(4).join(" ")
      put :update, :id => @user.id,
                    :user => {:name => "",
                              :custom_field => contact_params({:linetext => text, :all_ticket => "true", :testimony => Faker::Lorem.paragraph, 
                                                               :category => "Second", :text_regex_vdt => "Customer happiness"}),
                              :job_title => @user.job_title,
                              :phone => @user.phone,
                              :time_zone => @user.time_zone,
                              :language => @user.language 
                              }
      user = @account.users.find(@user.id)
      response.body.should =~ /prohibited this user from being saved/
      response.body.should =~ /Linetext with regex validation is not valid/
      user.name.should_not be_nil
      user.send("cf_category").should_not eql "Second"
      user.send("cf_date").should_not be_nil
    end
  end
end
