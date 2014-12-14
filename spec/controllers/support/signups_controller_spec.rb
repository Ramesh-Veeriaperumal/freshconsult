require 'spec_helper'

describe Support::SignupsController do
    setup :activate_authlogic
    self.use_transactional_fixtures = false

  before(:all) do
    @account.features.send(:signup_link).create
    @account.contact_form.fields.find_by_name("email").update_attributes(:editable_in_signup => true)
    @notification = @account.email_notifications.find_by_notification_type(EmailNotification::USER_ACTIVATION)
    @notification.update_attributes(:requester_notification => true)
  end
  
  context "For signup without custom fields" do

    it "should display new signup page" do
      get :new
      response.should render_template 'support/signups/new.portal'
      response.should be_success
    end

    it "should not display new signup page when user logged_in" do
      user = add_test_agent(@account)
      log_in(user)
      get :new
      response.redirected_to.should =~ /login/
      response.should_not be_success
    end

    it "should be successfully create new user" do
      test_email = Faker::Internet.email
      post 'create', :user => { :name => Faker::Name.name, :email => test_email }
      @account.user_emails.user_for_email(test_email).should be_an_instance_of(User)
      response.session[:flash][:notice].should eql "Activation link has been sent to #{test_email}"
    end

    it "should be successfully create new user without activation email" do
      @notification.update_attributes(:requester_notification => false)
      test_email = Faker::Internet.email
      post 'create', :user => { :name => Faker::Name.name, :email => test_email }
      response.session[:flash][:notice].should eql "Successfully registered"
      @account.user_emails.user_for_email(test_email).should be_an_instance_of(User)
    end

    it "should not create a new user without a email" do
      post :create, :user => { :name => Faker::Name.name, :email => "" }
      response.should render_template 'support/signups/new.portal'
    end

    it "should not create a new user with an invalid email" do
      post :create, :user => { :name => Faker::Name.name, :email => Faker::Lorem.sentence }
      response.should render_template 'support/signups/new.portal'
    end
  end

  context "For signup with custom fields" do

    before(:all) do
      @portal = @account.main_portal
      custom_field_params.each do |field|
        params = cf_params(field)
        create_contact_field params  
      end
    end

    after(:all) do
      Resque.inline = true
      custom_field_params.each { |params| 
        @account.contact_form.fields.find_by_name("cf_#{params[:label].strip.gsub(/\s/, '_').gsub(/\W/, '').gsub(/[^ _0-9a-zA-Z]+/,"").downcase}".squeeze("_")).delete_field }
      Resque.inline = false
    end

    it "should render new signup with custom fields" do
      @account.contact_form.fields.find_by_name("job_title").update_attributes(:editable_in_signup => true)
      get :new
      response.should render_template 'support/signups/new.portal'
      response.should be_success
      @account.contact_form.customer_signup_contact_fields.each { |field| response.body.should =~ /#{field[:label_in_portal]}/ }
      @account.contact_form.customer_signup_invisible_contact_fields.each { |field| response.body.should_not =~ /#{field[:label_in_portal]}/ }
    end

    it "should create a new contact with custom fields" do
      test_email = Faker::Internet.email
      text = Faker::Lorem.words(4).join(" ")
      para = Faker::Lorem.paragraph
      post :create, :user => { :name => Faker::Name.name,
                               :email => test_email,
                               :custom_field => {:cf_linetext => text, :cf_testimony => para}
                             }
      new_user = @account.user_emails.user_for_email(test_email)
      new_user.should be_an_instance_of(User)
      new_user.flexifield_without_safe_access.should_not be_nil
      new_user.send("cf_linetext").should eql(text)
      new_user.send("cf_testimony").should eql(para)
    end

    it "should strip-off invisible signup fields" do # only testimony and linetext fields are visiable(editable) in signup
      test_email = Faker::Internet.email
      text = Faker::Lorem.words(4).join(" ")
      para = Faker::Lorem.paragraph
      name = Faker::Name.name
      post :create, :user => { :name => name,
                               :custom_field => contact_params({:linetext => text, :testimony => para, :all_ticket => "false",
                                                 :agt_count => "34", :fax => Faker::PhoneNumber.phone_number, :url => Faker::Internet.url, 
                                                 :date => date_time, :category => "Tenth"}),
                               :email => test_email 
                              }
      new_user = @account.user_emails.user_for_email(test_email)
      new_user.should be_an_instance_of(User)
      new_user.flexifield_without_safe_access.should_not be_nil

      # only visible fields are saved.
      new_user.send("cf_linetext").should eql(text)
      new_user.send("cf_testimony").should eql(para)

      # invisible fields have been striped off
      new_user.send("cf_category").should be_nil
      new_user.send("cf_agt_count").should be_nil
      new_user.send("cf_show_all_ticket").should be_nil
      new_user.send("cf_file_url").should be_nil
    end

    it "should not create a user if mandatory fields has null values" do
      test_email = Faker::Internet.email
      post :create, :user => { :name => Faker::Name.name, :email => test_email,
                             :custom_field => {:cf_linetext => Faker::Lorem.words(4).join(" "), :cf_testimony => ""}
                           }
      response.body.should =~ /prohibited this user from being saved/
      response.body.should =~ /Testimony cannot be blank/
      @account.user_emails.user_for_email(test_email).should_not be_an_instance_of(User)
    end

    # REGEX VALIDATION :
    # custom_field "Linetext with regex validation" should either contain "desk" or "service" as a field value 
    # if field_value doesn't contain either of these words, request should throw an error message as "invalid value"
    
    it "should not create a new contact with invalid value in regex field" do
      test_email = Faker::Internet.email
      text = Faker::Lorem.words(4).join(" ")
      post :create, :user => { :name => Faker::Name.name, :email => test_email,
                               :custom_field => {:cf_linetext => text, :cf_testimony => Faker::Lorem.paragraph, 
                                                 :cf_linetext_with_regex_validation => "Freshkit" }
                             }
      response.body.should =~ /prohibited this user from being saved/
      response.body.should =~ /Linetext with regex validation is not valid/
      @account.user_emails.user_for_email(test_email).should_not be_an_instance_of(User)
    end

    it "should create a new contact" do # single line text with regex validation.
      test_email = Faker::Internet.email
      text = Faker::Lorem.words(4).join(" ")
      post :create, :user => { :name => Faker::Name.name, :email => test_email,
                               :custom_field => {:cf_linetext => text, :cf_testimony => Faker::Lorem.paragraph, 
                                                 :cf_linetext_with_regex_validation => "Freshservice product" }
                             }
      new_user = @account.user_emails.user_for_email(test_email)
      new_user.should be_an_instance_of(User)
      new_user.flexifield_without_safe_access.should_not be_nil
      new_user.send("cf_linetext").should eql(text)
      new_user.send("cf_linetext_with_regex_validation").should eql "Freshservice product"
    end
  end
end