require 'spec_helper'

RSpec.describe ContactsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    login_admin
    @user_count = @account.users.all.size
  end

  before(:all) do
    @sample_contact = FactoryGirl.build(:user, :account => @acc, :phone => "234234234234234", :email => Faker::Internet.email,
                              :user_role => 3)
    @sample_contact.save(:validate => false)
  end

  after(:each) do
    @account.features.multiple_user_emails.destroy
  end

  it "should not create a new contact without an email" do
    post :create, :user => { :name => Faker::Name.name, :email => "" }
    response.body.should =~ /Email is invalid/
  end

  it "should not allow to create more agents than allowed by the plan" do
    contact = FactoryGirl.build(:user)
    contact.save
    @account.subscription.update_attributes(:state => "active", :agent_limit => @account.full_time_agents.count)
    @request.env['HTTP_REFERER'] = 'sessions/new'
    put :make_agent, :id => contact.id
    @account.agents.find_by_user_id(contact.id).should be_nil
    @account.subscription.update_attributes(:state => "trial")
  end

  it "should not create a contact within a company" do
    new_company = FactoryGirl.build(:customer, :name => Faker::Name.name)
    new_company.save
    post :quick_contact_with_company, { :company_name => new_company.id, 
                                        :user => { :name => Faker::Name.name, 
                                                   :email => @sample_contact.email, 
                                                   :phone => "" }, 
                                        :id => new_company.id
                                        }
    @account.users.all.size.should eql @user_count
    response.should redirect_to(company_url(new_company.id))
  end

  it "should not edit a contact" do
    contact = FactoryGirl.build(:user, :account => @acc, :email => Faker::Internet.email,
                              :user_role => 3)
    contact.save(:validate => false)
    test_email = Faker::Internet.email
    test_phone_no = Faker::PhoneNumber.phone_number
    put :update, :id => contact.id, :user => { :email => @sample_contact.email, 
                                                :job_title => "Developer",
                                                :phone => test_phone_no,
                                                :time_zone => contact.time_zone, 
                                                :language => contact.language }
    response.body.should =~ /Email has already been taken/
  end

  it "should fail create for existing email" do
    post :create, :user => { :name => Faker::Name.name, :email => @sample_contact.email , :time_zone => "Chennai", :language => "en" }
    response.body.should =~ /Email has already been taken/
    @account.users.all.size.should eql @user_count
  end

  it "should fail create for no credentials" do
    post :create, :user => { :name => Faker::Name.name, :time_zone => "Chennai", :language => "en" }
    response.body.should =~ /Email is invalid/   
    @account.users.all.size.should eql @user_count
  end

  it "should fail making a customer a full-time agent" do
    @account.subscription.update_attributes(:agent_limit => 1)
    customer = FactoryGirl.build(:user, :account => @acc, :email => Faker::Internet.email,
                              :user_role => 3)
    customer.save
    put :make_agent, :id => customer.id
    response.should redirect_to(@request.env['HTTP_REFERER'])
    @account.subscription.update_attributes(:agent_limit => nil)
  end

  # it "should fail user creation MUE feature enabled" do
  #   user = add_new_user(@account)
  #   @user_count = @user_count + 1
  #   @account.features.multiple_user_emails.create
  #   test_email = user.email
  #   post :create, :user => { :name => Faker::Name.name, :user_emails_attributes => {"0" => {:email => test_email}} , :time_zone => "Chennai", :language => "en" }
  #   @account.users.all.size.should eql @user_count
  #   response.body.should =~ /Email has already been taken/
  #   @account.features.multiple_user_emails.destroy
  # end

  it "should unblock an user" do
    contact = FactoryGirl.build(:user, :account => @acc, :phone => "4564564656456", 
                                                     :blocked => true, 
                                                     :email => Faker::Internet.email,
                                                     :user_role => 3, 
                                                     :deleted => true, 
                                                     :deleted_at => Time.now)
    contact.save(:validate => false)
    ticket = create_ticket({ :requester_id => contact.id })
    Resque.inline = true
#    User.any_instance.stubs(:update_without_callbacks).raises(StandardError)
    get :unblock, :id => contact.id
    User.any_instance.unstub(:update_without_callbacks)
    Resque.inline = false
    Account.any_instance.unstub(:users)
    contact.reload
    contact.blocked.should eql false
    response.should redirect_to(contact_path(contact.id))
  end
end
