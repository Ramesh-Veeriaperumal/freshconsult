require 'spec_helper'

describe ContactsController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account = create_test_account
    @user = add_test_agent(@account)
  end

  before(:each) do
    @request.host = @account.full_domain
    @request.user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36 
                                        (KHTML, like Gecko) Chrome/32.0.1700.107 Safari/537.36"
    log_in(@user)
  end

  it "should create a new contact" do
    test_email = Faker::Internet.email
    post :create, :user => { :email => test_email , :time_zone => "Chennai", :language => "en" }
    @account.contacts.find_by_email(test_email).should be_an_instance_of(User)
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
    new_contact = @account.contacts.find_by_email(test_email)
    new_contact.should be_an_instance_of(User)
    new_contact.customer_id.should be_eql(new_company.id)
  end

  it "should edit an existing contact" do
    contact = Factory.build(:user, :account => @acc, :email => Faker::Internet.email,
                              :user_role => 3)
    contact.save
    get :edit, :id => contact.id
    response.body.should =~ /Edit Contact/
    test_email = Faker::Internet.email
    test_phone_no = Faker::PhoneNumber.phone_number
    put :update, :id => contact.id, :user => { :email => test_email, 
                                                :job_title => "Developer",
                                                :phone => test_phone_no,
                                                :time_zone => contact.time_zone, 
                                                :language => contact.language }
    edited_contact = @account.contacts.find_by_email(test_email)
    edited_contact.should be_an_instance_of(User)
    edited_contact.phone.should be_eql(test_phone_no)
  end

  it "should make a customer a full-time agent" do
    @account.subscription.update_attributes(:agent_limit => 30)
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

  it "should delete an existing contact" do
    customer = Factory.build(:user, :account => @acc, :email => Faker::Internet.email,
                              :user_role => 3)
    customer.save
    @request.env['HTTP_REFERER'] = 'sessions/new'
    delete :destroy, :id => customer.id
    @account.all_users.find(customer.id).deleted.should be_true
  end
end