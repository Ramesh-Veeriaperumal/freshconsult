require 'spec_helper'

describe ContactsController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    login_admin
    @user_count = @account.users.all.size
    stub_s3_writes
  end

  before(:all) do
    @sample_contact = Factory.build(:user, :account => @acc, :phone => "23423423434", :email => Faker::Internet.email,
                              :user_role => 3)
    @sample_contact.save
    @active_contact = Factory.build(:user, :name => "1111", :account => @acc, :phone => "234234234234234", :email => Faker::Internet.email,
                              :user_role => 3, :active => true)
    @active_contact.save
    @new_company = Factory.build(:company)
    @new_company.save
  end

  after(:each) do
    @account.features.multiple_user_emails.destroy
  end

  #A few exceptions have been missed and agent failures couldnt be reproduced

  it "should create a new contact" do
    test_email = Faker::Internet.email
    post :create, :user => { :name => Faker::Name.name, :email => test_email , :time_zone => "Chennai", :language => "en" }
    @account.user_emails.user_for_email(test_email).should be_an_instance_of(User)
    @account.users.all.size.should eql @user_count+1
    u = @account.user_emails.user_for_email(test_email)
    Delayed::Job.last.handler.should include("deliver_user_activation")
    Delayed::Job.last.handler.should include(u.name)
  end

  it "should create a new contact with new company" do # with old company parameters(customer deprecation)
    test_email = Faker::Internet.email
    company_name = Faker::Name.name
    post :create, :user => { :name => Faker::Name.name, :email => test_email , :time_zone => "Chennai", :language => "en", :customer => company_name }
    @account.user_emails.user_for_email(test_email).should be_an_instance_of(User)
    @account.users.all.size.should eql @user_count+1
    u = @account.user_emails.user_for_email(test_email)
    @account.companies.find_by_name(company_name).should be_an_instance_of(Customer)
    Delayed::Job.last.handler.should include("deliver_user_activation")
    Delayed::Job.last.handler.should include(u.name)
  end

   it "should create a new contact with new company" do # with new company parameters(customer deprecation)
    test_email = Faker::Internet.email
    company_name = Faker::Name.name
    post :create, :user => {:name => Faker::Name.name, :job_title=>"Developer",:email => test_email , :time_zone => "Chennai", 
                            :language => "en", :company_name => company_name }
    @account.user_emails.user_for_email(test_email).should be_an_instance_of(User)
    @account.users.all.size.should eql @user_count+1
    @account.companies.find_by_name(company_name).should be_an_instance_of(Customer)
  end

  it "should create a new contact - nmobile format" do
    test_email = Faker::Internet.email
    post :create, :user => { :name => Faker::Name.name, :email => test_email , :time_zone => "Chennai", :language => "en" }, :format =>'nmobile'
    @account.user_emails.user_for_email(test_email).should be_an_instance_of(User)
    @account.users.all.size.should eql @user_count+1
    u = @account.user_emails.user_for_email(test_email)
    Delayed::Job.last.handler.should include("deliver_user_activation")
    Delayed::Job.last.handler.should include(u.name)
  end

  it "should create a new contact - json format" do
    test_email = Faker::Internet.email
    post :create, :user => { :name => Faker::Name.name, :email => test_email , :time_zone => "Chennai", :language => "en", :tags => "phonecontact" }, :format => 'json'
    @account.user_emails.user_for_email(test_email).should be_an_instance_of(User)
    @account.users.all.size.should eql @user_count+1
    u = @account.user_emails.user_for_email(test_email)
    Delayed::Job.last.handler.should include("deliver_user_activation")
    Delayed::Job.last.handler.should include(u.name)
  end
  
  it "should create a new contact with email - js format" do
    test_email = Faker::Internet.email
    post :create, :user => { :name => Faker::Name.name, :email => test_email , :time_zone => "Chennai", :language => "en"}, :format => 'js'
   
    @account.user_emails.user_for_email(test_email).should be_an_instance_of(User)
    @account.users.all.size.should eql @user_count+1
    u = @account.user_emails.user_for_email(test_email)
    Delayed::Job.last.handler.should include("deliver_user_activation")
    Delayed::Job.last.handler.should include(u.name)
  end
  
  it "should create a new contact with phone number - js format" do
    phone_number = Faker::PhoneNumber.phone_number
    post :create, :user => { :name => Faker::Name.name, :phone => phone_number, :time_zone => "Chennai", :language => "en"}, :format => 'js'
    @account.users.find_by_phone(phone_number).should be_an_instance_of(User)
    @account.users.all.size.should eql @user_count+1
  end
  
  it "should create a new contact with mobile no- js format" do
    mobile_no = Faker::PhoneNumber.cell_phone
    post :create, :user => { :name => Faker::Name.name, :mobile => mobile_no, :time_zone => "Chennai", :language => "en"}, :format => 'js'
    @account.users.find_by_mobile(mobile_no).should be_an_instance_of(User)
    @account.users.all.size.should eql @user_count+1
  end
  
  it "should create a new contact with twitter_id - js format" do
    twitter_id = "twitter_user_#{rand(100)}"
    post :create, :user => { :name => Faker::Name.name, :twitter_id => twitter_id, :time_zone => "Chennai", :language => "en"}, :format => 'js'
    @account.users.find_by_twitter_id(twitter_id).should be_an_instance_of(User)
    @account.users.all.size.should eql @user_count+1
  end
  
  it "should list all contacts created" do
    get :index
    response.body.should =~ /#{@active_contact.email}/
  end
  
  it "should list all non-verified contacts" do
    unverified_contact = Factory.build(:user, :account => @account, :phone => "234234234234", :email => Faker::Internet.email,
                              :user_role => 3, :active => false)
    unverified_contact.save
    get :index, {:state => "unverified", :letter => []}
    response.body.should =~ /#{unverified_contact.email}/
  end

  it "should list all blocked contacts" do
    blocked_contact = Factory.build(:user, :account => @account, :phone => "234234234234", :email => Faker::Internet.email,
                              :user_role => 3, :active => false, 
                              :blocked => true, :blocked_at =>  Time.now + 2.days, 
                              :deleted => true, :deleted_at => Time.now + 3.days)
    blocked_contact.save
    get :index, {:state => "blocked", :letter => []}
    response.body.should =~ /#{blocked_contact.email}/
  end

  it "should list all deleted contacts" do
    deleted_contact = Factory.build(:user, :account => @account, :phone => "234234234234", :email => Faker::Internet.email,
                              :user_role => 3, :active => false, 
                              :deleted => true)
    deleted_contact.save
    get :index, {:state => "deleted", :letter => []}
    response.body.should =~ /#{deleted_contact.email}/
  end
  
  it "should list all contacts created xml" do
    get :index, :format => 'xml'
    response.body.should =~ /#{@active_contact.email}/
  end

  it "should list all contacts created json" do
    get :index, :format => 'json'
    response.body.should =~ /#{@active_contact.email}/
  end

  it "should list all contacts created nmobile" do
    get :index, :format => 'nmobile'
    response.body.should =~ /#{@active_contact.email}/
  end

  it "should list contact with tag" do
    contact = Factory.build(:user, :account => @acc, :phone => "2342342456454234", :email => Faker::Internet.email,
                              :user_role => 3, :active => true)
    contact.save
    contact.tags.create({:name => "amazing"})
    tag = contact.tags.first
    get :index, :tag => tag.id
    response.body.should =~ /#{contact.email}/
    response.body.should_not =~ /#{@sample_contact.email}/
  end

  # it "should list all contacts created" do
  #   contact = Factory.build(:user, :account => @acc, :phone => "23423422334234", :email => Faker::Internet.email,
  #                             :user_role => 3, :active => true)
  #   contact.save(false)
  #   get :index, :format => 'atom'
  #   response.body.should =~ /#{contact.email}/
  # end

  it "should list all contacts matching the query" do
    contact = Factory.build(:user, :account => @acc, :phone => "23423422334234", :email => Faker::Internet.email,
                              :user_role => 3, :active => true)
    contact.save
    contact.reload
    get :index, :format => 'xml', :query => "email is #{contact.email}"
    response.body.should =~ /#{contact.email}/
    response.body.should_not =~ /#{@sample_contact.email}/
  end

  it "should list deleted contacts matching the query with filter condition as deleted state" do
    contact = Factory.build(:user, :account => @acc, :phone => "23423422334234", :email => Faker::Internet.email,
                              :user_role => 3, :active => false, 
                              :deleted => true)
    contact.save
    get :index,:state => "deleted", :letter => [],:format => 'xml', :query => "email is #{contact.email}"
    response.body.should =~ /#{contact.email}/
    response.body.should_not =~ /#{@sample_contact.email}/
  end

  it "should give all details of a contact with id" do
    contact = Factory.build(:user, :account => @acc, :email => Faker::Internet.email,
                              :user_role => 3)
    contact.save
    contact.reload
    get :show, :id => contact.id
    response.body.should =~ /#{contact.email}/
  end

  it "should give all details of a contact with id in json" do
    contact = Factory.build(:user, :account => @acc, :email => Faker::Internet.email,
                              :user_role => 3)
    contact.save
    contact.reload
    get :show, :id => contact.id, :format => 'json'
    response.body.should =~ /#{contact.email}/
  end

  it "should give all details of a contact with email" do
    contact = Factory.build(:user, :account => @acc, :phone => "456564564564899", :email => Faker::Internet.email,
                              :user_role => 3)
    contact.save
    contact.reload
    get :show, :email => contact.email
    response.body.should =~ /#{contact.phone}/
  end

  it "should show hover card" do
    get :hover_card, :id => @sample_contact.id
    response.body.should =~ /#{@sample_contact.email}/
  end

  it "should render for new user" do
    get :new
    response.should render_template('contacts/new')
  end

  it "should unblock an user" do
    contact = Factory.build(:user, :account => @acc, :phone => "4564564656456", :blocked => true, :email => Faker::Internet.email,
                              :user_role => 3, :deleted => true, :deleted_at => Time.now)
    contact.save
    ticket = create_ticket({ :requester_id => contact.id })
    Resque.inline = true
    get :unblock, :id => contact.id
    Resque.inline = false
    contact.reload
    contact.blocked.should eql false
    response.should redirect_to(contact_path(contact.id))
  end

  it "should find contact with partial name" do
    new_company = Factory.build(:customer, :name => Faker::Name.name)
    new_company.save
    get :autocomplete, :v => new_company.name[0..2], :format => 'json'
    response.body.should =~ /#{new_company.name}/
  end

  it "widget contact email for existing contact" do
    get :contact_email, :email => @sample_contact.email, :format => 'widget'
    response.body.should =~ /#{@sample_contact.name}/
  end

  it "widget contact email for new contact" do
    get :contact_email, :email => Faker::Internet.email, :format => 'widget'
    response.should render_template('contacts/new')
  end

  it "should configure for contact export" do
    post :configure_export
    response.body.should =~ /Export active contacts to a CSV file./
  end

  it "should export csv" do
    post :export_csv, "data_hash"=>"", "export_fields"=>{"Name"=>"name", "Email"=>"email", "Job Title"=>"job_title", "Company"=>"company_name", "Phone"=>"phone"}
    response.header["Content-type"].should eql 'text/csv; charset=utf-8; header=present'
    response.body.should include "Name,Email,Job Title,Company,Phone"
  end

  it "should create a quick contact" do
    test_phone_no = Faker::PhoneNumber.phone_number
    post :create, :user => { :name => Faker::Name.name, :email => "", :phone => test_phone_no }
    @account.contacts.find_by_phone(test_phone_no).should be_an_instance_of(User)
  end

  it "should create a quick contact within a company" do # with new company parameters(customer deprecation)
    test_email = Faker::Internet.email
    post :quick_contact_with_company, { :user => { :name => Faker::Name.name, 
                                                   :email => test_email, 
                                                   :phone => "",
                                                   :company_name => @new_company.name }, 
                                      }
    new_contact = @account.user_emails.user_for_email(test_email)
    new_contact.should be_an_instance_of(User)
    new_contact.company_id.should be_eql(new_company.id)
    Delayed::Job.last.handler.should include("deliver_user_activation")
    Delayed::Job.last.handler.should include(new_contact.name)
  end

  it "should edit an existing contact" do
    contact = Factory.build(:user, :account => @acc, :email => Faker::Internet.email,
                              :user_role => 3, :active => 1, :password => "test")
    contact.save
    get :edit, :id => contact.id
    response.body.should =~ /Edit Contact/
    test_email = Faker::Internet.email
    puts test_email
    puts "\n\n\n"
    test_phone_no = Faker::PhoneNumber.phone_number
    put :update, :id => contact.id, :user => { :email => test_email, 
                                                :job_title => "Developer",
                                                :phone => test_phone_no,
                                                :time_zone => contact.time_zone, 
                                                :language => contact.language }
    @account.reload
    edited_contact = @account.user_emails.user_for_email(test_email)
    edited_contact.should be_an_instance_of(User)
    edited_contact.phone.should be_eql(test_phone_no)
    Delayed::Job.last.handler.should include("deliver_user_activation")
    Delayed::Job.last.handler.should include(edited_contact.name)
  end

  it "should update an existing contact" do # with new company parameters(customer deprecation)
    contact = Factory.build(:user, :account => @acc, :email => Faker::Internet.email,
                              :user_role => 3)
    contact.save
    test_email = Faker::Internet.email
    test_phone_no = Faker::PhoneNumber.phone_number
    put :update, :id => contact.id, :user => { :email => test_email, 
                                                :job_title => "Developer",
                                                :phone => test_phone_no,
                                                :time_zone => contact.time_zone,
                                                :company_name => @new_company.name, 
                                                :language => contact.language }
    edited_contact = @account.user_emails.user_for_email(test_email)
    edited_contact.should be_an_instance_of(User)
    edited_contact.phone.should be_eql(test_phone_no)
    edited_contact.company_id.should eql @new_company.id
  end

  it "should edit an existing contact and create new company" do # with old company parameters(customer deprecation)
    contact = Factory.build(:user, :account => @acc, :email => Faker::Internet.email,
                              :user_role => 3, :active => 1, :password => "test")
    contact.save
    get :edit, :id => contact.id
    response.body.should =~ /Edit Contact/
    test_email = Faker::Internet.email
    test_phone_no = Faker::PhoneNumber.phone_number
    put :update, :id => contact.id, :user => { :email => test_email, 
                                                :job_title => "Developer",
                                                :phone => test_phone_no,
                                                :time_zone => contact.time_zone,
                                                :customer => "testcompany", 
                                                :language => contact.language }
    edited_contact = @account.user_emails.user_for_email(test_email)
    edited_contact.should be_an_instance_of(User)
    edited_contact.phone.should be_eql(test_phone_no)
    @account.companies.find_by_name("testcompany").should be_an_instance_of(Customer)
    Delayed::Job.last.handler.should include("deliver_user_activation")
    Delayed::Job.last.handler.should include(edited_contact.name)
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

  # it "should delete avatar" do
  #   customer = Factory.build(:user, :account => @acc, :email => Faker::Internet.email,
  #                             :user_role => 3, :avatar_attributes => { :content => Rack::Test::UploadedFile.new('spec/fixtures/files/image4kb.png', 'image/png')})
  #   customer.save  
  #   customer.reload
  #   put :delete_avatar, :id => customer.id
  #   puts response.status.inspect
  #   customer.reload
  #   customer.avatar.should eql nil
  #   response.body.should =~ /success/
  # end

  it "should make a customer an occasional agent" do
    occasional_customer = Factory.build(:user, :account => @acc, :email => Faker::Internet.email,
                              :user_role => 3)
    occasional_customer.save
    occasional_customer.reload
    put :make_occasional_agent, :id => occasional_customer.id
    occasional_agent = @account.agents.find_by_user_id(occasional_customer.id)
    occasional_agent.should be_an_instance_of(Agent)
    occasional_agent.occasional.should be_true
  end

  it "should restore a deleted contact" do
    customer = Factory.build(:user, :account => @acc, :email => Faker::Internet.email,
                              :user_role => 3, :deleted => true)
    customer.save
    put :restore, :id => customer.id
    customer.reload
    customer.deleted?.should eql false
  end

  it "should restore a deleted contact - Js format" do
    customer = Factory.build(:user, :account => @acc, :email => Faker::Internet.email,
                              :user_role => 3, :deleted => true)
    customer.save
    put :restore, :id => customer.id, :format => 'js'
    customer.reload
    customer.deleted?.should eql false
  end

  it "should delete an existing contact" do
    customer = Factory.build(:user, :account => @acc, :email => Faker::Internet.email,
                              :user_role => 3)
    customer.save
    customer.reload
    delete :destroy, :id => customer.id
    @account.all_users.find(customer.id).deleted.should be_true
  end

  #### Company revamp specs - User Tags Revamp Specs

  it "should create a contact given the names of the tags as :tag_names in params" do #newway
    tag_names = "#{Faker::Name.first_name}, #{Faker::Name.first_name}"
    fake_a_contact
    @params[:user].merge!(:tag_names => tag_names)
    post :create, @params
    contact = @account.contacts.find_by_name(@params[:user][:name])
    contact.tag_names.should eql(tag_names)
  end

  it "should create a contact given the names of the tags as :tags in params" do #oldway
    tags = "#{Faker::Name.first_name}, #{Faker::Name.first_name}"
    fake_a_contact
    @params[:user].merge!(:tags => tags)
    post :create, @params
    contact = @account.contacts.find_by_name(@params[:user][:name])
    contact.tag_names.should eql(tags)
  end

  it "should update a contact given the names of the tags as :tag_names in params" do #newway
    tag_names = "#{Faker::Name.first_name}, #{Faker::Name.first_name}"
    user      = add_new_user(@account)
    fake_a_contact
    @params.merge!(:id => user.id)
    @params[:user].merge!(:tag_names => tag_names)
    put :update, @params
    contact = @account.contacts.find_by_name(@params[:user][:name])
    tag_names.split(',').all? do |tag_name|
      contact.tag_names.should include(tag_name)
    end
  end

  it "should update a contact given the names of the tags as :tags in params" do #oldway
    tags = "#{Faker::Name.first_name}, #{Faker::Name.first_name}"
    user = add_new_user(@account)
    fake_a_contact
    @params.merge!(:id => user.id)
    @params[:user].merge!(:tags => tags)
    put :update, @params
    contact = @account.contacts.find_by_name(@params[:user][:name])
    tags.split(',').all? do |tag|
      contact.tag_names.should include(tag)
    end
  end

  it "should create a contact with :tag_names given both :tags and :tag_names in params" do #newway
    tag_names = "#{Faker::Name.first_name}, #{Faker::Name.first_name}"
    tags = "#{Faker::Name.first_name}, #{Faker::Name.first_name}"
    fake_a_contact
    @params[:user].merge!(:tag_names => tag_names, :tags => tags)
    post :create, @params
    contact = @account.contacts.find_by_name(@params[:user][:name])
    contact.tag_names.should eql(tag_names)
    contact.tag_names.should_not eql(tags)
  end

  it "should update a contact with :tag_names given both :tags and :tag_names in params" do #oldway
    tag_names = "#{Faker::Name.first_name}, #{Faker::Name.first_name}"
    tags = "#{Faker::Name.first_name}, #{Faker::Name.first_name}"
    user = add_new_user(@account)
    fake_a_contact
    @params.merge!(:id => user.id)
    @params[:user].merge!(:tag_names => tag_names, :tags => tags)
    put :update, @params
    contact = @account.contacts.find_by_name(@params[:user][:name])
    tag_names.split(',').all? do |tag_name|
      contact.tag_names.should include(tag_name)
    end
    tags.split(',').all? do |tag|
      contact.tag_names.should_not include(tag)
    end
  end
  
  it "should not update tag_names of a contact when they are nil in params" do
    tag_names = "#{Faker::Name.first_name}, #{Faker::Name.first_name}"
    user = add_new_user(@account)
    user.reload # for user_emails to refresh
    user.update_attributes(:tag_names => tag_names)
    user.reload
    user.tag_names.should eql(tag_names)
    fake_a_contact
    @params.merge!(:id => user.id)
    @params[:user].merge!(:tag_names => nil)
    put :update, @params
    user.reload
    user.tag_names.should eql(tag_names)
  end

  it "should clear tag_names of a contact when they are '' in params" do
    tag_names = "#{Faker::Name.first_name}, #{Faker::Name.first_name}"
    user = add_new_user(@account)
    user.reload # for user_emails to refresh
    user.update_attributes!(:tag_names => tag_names)
    user.reload
    user.tag_names.should eql(tag_names)
    fake_a_contact
    @params.merge!(:id => user.id)
    @params[:user].merge!(:tag_names => '')
    put :update, @params
    user.reload
    user.tag_names.should eql('')
  end

  it "should not raise Name can't be blank error for tags,
      instead clear tags when tag_names is ' ' in params" do
    tag_names = "#{Faker::Name.first_name}, #{Faker::Name.first_name}"
    user = add_new_user(@account)
    user.reload # for user_emails to refresh
    user.update_attributes(:tag_names => tag_names)
    user.reload
    user.tag_names.should eql(tag_names)
    fake_a_contact
    @params.merge!(:id => user.id)
    @params[:user].merge!(:tag_names => ' ')
    put :update, @params
    user.reload
    user.tag_names.should eql('')
  end

end
