require 'spec_helper'

describe ContactsController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    login_admin
  end

  it "should create a new contact" do
    test_email = Faker::Internet.email
    post :create, :user => { :name => Faker::Name.name, :email => test_email , :time_zone => "Chennai", :language => "en" }
    @account.user_emails.user_for_email(test_email).should be_an_instance_of(User)
  end

  it "should create a quick contact" do
    test_phone_no = Faker::PhoneNumber.phone_number
    post :create, :user => { :name => Faker::Name.name, :email => "", :phone => test_phone_no }
    @account.contacts.find_by_phone(test_phone_no).should be_an_instance_of(User)
  end

  it "should create a contact within a company" do
    new_company = Factory.build(:customer, :name => Faker::Name.name)
    new_company.save
    test_email = Faker::Internet.email
    post :quick_customer, { :customer_id => new_company.id, 
                            :user => { :name => Faker::Name.name, 
                                       :email => test_email, 
                                       :phone => "" }, 
                            :id => new_company.id
                            }
    new_contact = @account.user_emails.user_for_email(test_email)
    new_contact.should be_an_instance_of(User)
    new_contact.customer_id.should be_eql(new_company.id)
  end

  it "should edit an existing contact" do
    contact = Factory.build(:user, :account => @acc, :email => Faker::Internet.email,
                              :user_role => 3)
    contact.save(false)
    get :edit, :id => contact.id
    response.body.should =~ /Edit Contact/
    test_email = Faker::Internet.email
    test_phone_no = Faker::PhoneNumber.phone_number
    put :update, :id => contact.id, :user => { :email => test_email, 
                                                :job_title => "Developer",
                                                :phone => test_phone_no,
                                                :time_zone => contact.time_zone, 
                                                :language => contact.language }
    edited_contact = @account.user_emails.user_for_email(test_email)
    edited_contact.should be_an_instance_of(User)
    edited_contact.phone.should be_eql(test_phone_no)
  end

  it "should make a customer a full-time agent" do
    @account.subscription.update_attributes(:agent_limit => nil)
    @request.env['HTTP_REFERER'] = 'sessions/new'
    customer = Factory.build(:user, :account => @acc, :email => Faker::Internet.email,
                              :user_role => 3)
    customer.save
    put :make_agent, :id => customer.id
    full_time_agent = @account.agents.find_by_user_id(customer.id)
    full_time_agent.should be_an_instance_of(Agent)
    full_time_agent.occasional.should be_false
  end

  it "should make a customer an occasional agent" do
    occasional_customer = Factory.build(:user, :account => @acc, :email => Faker::Internet.email,
                              :user_role => 3)
    occasional_customer.save
    put :make_occasional_agent, :id => occasional_customer.id
    occasional_agent = @account.agents.find_by_user_id(occasional_customer.id)
    occasional_agent.should be_an_instance_of(Agent)
    occasional_agent.occasional.should be_true
  end

  it "should verify an email" do
    if @account.features?(:multiple_user_emails)
      @user2 = add_user_with_multiple_emails(@account, 4)
      last_id = @user2.user_emails.last.id
      post :verify_email, :email_id => last_id
      response.body.should =~ /Activation mail sent/
      Delayed::Job.last.handler.should include("deliver_email_activation")
    end
  end

  it "should delete an existing contact" do
    customer = Factory.build(:user, :account => @acc, :email => Faker::Internet.email,
                              :user_role => 3)
    customer.save
    @request.env['HTTP_REFERER'] = 'sessions/new'
    delete :destroy, :id => customer.id
    @account.all_users.find(customer.id).deleted.should be_true
  end
end
