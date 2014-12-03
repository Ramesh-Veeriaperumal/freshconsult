require 'spec_helper'

describe ContactsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    login_admin
    @user_count = @account.users.all.size
    stub_s3_writes
  end

  before(:all) do
    @account.reload
    @key_state = mue_key_state(@account)
    enable_mue_key(@account)
    @account.features.multiple_user_emails.create
    @account.features.contact_merge_ui.create
    @sample_contact = FactoryGirl.build(:user, :account => @acc, :phone => "23423423434", :email => Faker::Internet.email,
                              :user_role => 3)
    @sample_contact.save
    @active_contact = FactoryGirl.build(:user, :name => "1111", :account => @acc, :phone => "234234234234234", :email => Faker::Internet.email,
                              :user_role => 3, :active => true)
    @active_contact.save
  end

  after(:all) do
    @account.features.contact_merge_ui.destroy
    @account.features.multiple_user_emails.destroy
    disable_mue_key(@account) unless @key_state
  end  

  it "should create for wrong params with MUE feature" do
    test_email = Faker::Internet.email
    post :create, :user => { :name => Faker::Name.name, :email => test_email , :time_zone => "Chennai", :language => "en" }
    @account.user_emails.user_for_email(test_email).should be_an_instance_of(User)
    u = @account.user_emails.user_for_email(test_email)
    @account.users.all.size.should eql @user_count+1
    Delayed::Job.last.handler.should include("deliver_user_activation")
    Delayed::Job.last.handler.should include(u.name)
  end

  it "should create for without email with MUE feature" do
    test_email = Faker::Internet.email
    post :create, :user => { :name => Faker::Name.name, :phone => "7129837192381231" , :time_zone => "Chennai", :language => "en" }
    @account.users.all.size.should eql @user_count+1
    @account.users.find_by_phone("7129837192381231").should be_an_instance_of(User)
  end

  it "should not create for no attributes with MUE feature" do
    test_email = Faker::Internet.email
    post :create, :user => { :name => Faker::Name.name, :time_zone => "Chennai", :language => "en" }
    @account.users.all.size.should eql @user_count
    response.body.should =~ /Please enter at least one contact detail/  
  end

  it "should not create for blank primary email with MUE feature" do
    test_email = Faker::Internet.email
    post :create, :user => { :name => Faker::Name.name, :user_emails_attributes => {
                                                        "0" => { "email"=>"", "_destroy"=>"", "primary_role" => "1"}, 
                                                        },
                                                        :time_zone => "Chennai", :language => "en" }
    @account.users.all.size.should eql @user_count
    response.body.should =~ /Email is invalid/ 
  end

  it "should create for blank secondary email with MUE feature" do
    test_email = Faker::Internet.email
    post :create, :user => { :name => Faker::Name.name, :user_emails_attributes => {
                                                        "0" => { "email"=>test_email, "_destroy"=>"", "primary_role" => "1"}, 
                                                        "1" => { "email"=>"", "_destroy"=> ""}},
                                                        :time_zone => "Chennai", :language => "en" }
    @account.users.all.size.should eql @user_count+1
    @account.user_emails.user_for_email(test_email).should be_an_instance_of(User)
    u = @account.user_emails.user_for_email(test_email)
    Delayed::Job.last.handler.should include("deliver_user_activation")
    Delayed::Job.last.handler.should include(u.name)
  end

  it "should create new contact with MUE UI" do
    test_email = Faker::Internet.email
    post :create, :user=>{:name => Faker::Name.name, :user_emails_attributes => {
                                                        "0" => { "email"=>test_email, "_destroy"=>"", "primary_role" => "1"}, 
                                                        "1" => { "email"=>Faker::Internet.email, "_destroy"=> ""}
                                                      }                            
                         }
    @account.reload
    @account.user_emails.user_for_email(test_email).should be_an_instance_of(User)
    @account.users.all.size.should eql @user_count+1
    u = @account.user_emails.user_for_email(test_email)
    Delayed::Job.last.handler.should include("deliver_user_activation")
    Delayed::Job.last.handler.should include(u.name)
  end

  it "should create new contact with MUE UI without primary email" do
    test_email = Faker::Internet.email
    post :create, :user=>{:name => Faker::Name.name, :user_emails_attributes => {
                                                        "0" => { "email"=>test_email, "_destroy"=>""}, 
                                                        "1" => { "email"=>Faker::Internet.email, "_destroy"=> ""}
                                                      }                            
                         }
    @account.reload
    @account.user_emails.user_for_email(test_email).should be_an_instance_of(User)
    @account.users.all.size.should eql @user_count+1
    u = @account.user_emails.user_for_email(test_email)
    Delayed::Job.last.handler.should include("deliver_user_activation")
    Delayed::Job.last.handler.should include(u.name)
  end

  it "should add a email to contact" do
    user1 = add_user_with_multiple_emails(@account, 1)
    test_email = Faker::Internet.email
    put :update, :id => user1.id, :user=>{:name => user1.name, :user_emails_attributes => {
                                                        "0" => { "email"=>user1.email, "_destroy"=>"", "id" => user1.primary_email.id}, 
                                                        "1" => { "email"=>user1.user_emails.last.email, "_destroy"=>"", "id" => user1.user_emails.last.id},
                                                        "2" => { "email"=>test_email, "_destroy"=>""}
                                                      }                            
                         }
    user1.reload
    user1.user_emails.find_by_email(test_email).should be_an_instance_of(UserEmail)
    user1.user_emails.size.should eql 3
    @account.user_emails.user_for_email(test_email).should be_an_instance_of(User)
    u = @account.user_emails.user_for_email(test_email)
    Delayed::Job.last.handler.should include(u.name)
    Delayed::Job.last.handler.should include("deliver_email_activation")
  end

  it "should update a primary_email" do
    user1 = add_user_with_multiple_emails(@account, 1)
    test_email = Faker::Internet.email
    put :update, :id => user1.id, :user=>{:name => user1.name, :user_emails_attributes => {
                                                        "0" => { "email"=>test_email, "_destroy"=>"", "id" => user1.primary_email.id}, 
                                                        "1" => { "email"=>user1.user_emails.last.email, "_destroy"=>"", "id" => user1.user_emails.last.id}                                                      }                            
                         }
    user1.reload
    user1.user_emails.find_by_email(test_email).should be_an_instance_of(UserEmail)
    user1.user_emails.size.should eql 2
    @account.user_emails.user_for_email(test_email).should be_an_instance_of(User)
    u = @account.user_emails.user_for_email(test_email)
    u.email.should eql u.actual_email
    u.primary_email.verified.should eql false
    u.active.should eql false
    Delayed::Job.last.handler.should include(u.name)
    Delayed::Job.last.handler.should include("deliver_user_activation")
  end

  it "should update a secondary email" do
    user1 = add_user_with_multiple_emails(@account, 1)
    test_email = Faker::Internet.email
    put :update, :id => user1.id, :user=>{:name => user1.name, :user_emails_attributes => {
                                                        "0" => { "email"=>user1.email, "_destroy"=>"", "id" => user1.primary_email.id}, 
                                                        "1" => { "email"=>test_email, "_destroy"=>"", "id" => user1.user_emails.last.id}                                                      }                            
                         }
    user1.reload
    user1.user_emails.find_by_email(test_email).should be_an_instance_of(UserEmail)
    user1.user_emails.size.should eql 2
    @account.user_emails.user_for_email(test_email).should be_an_instance_of(User)
    u = @account.user_emails.user_for_email(test_email)
    Delayed::Job.last.handler.should include(u.name)
    Delayed::Job.last.handler.should include("deliver_email_activation")
  end

  it "should delete a secondary email" do
    user1 = add_user_with_multiple_emails(@account, 1)
    test_email = Faker::Internet.email
    case_email = user1.user_emails.last.email
    put :update, :id => user1.id, :user=>{:name => user1.name, :user_emails_attributes => {
                                                        "0" => { "email"=>user1.email, "_destroy"=>"", "id" => user1.primary_email.id}, 
                                                        "1" => { "email"=>user1.user_emails.last.email, "_destroy"=>"1", "id" => user1.user_emails.last.id},
                                                        "2" => { "email"=>test_email, "_destroy"=>""}
                                                      }                            
                         }
    user1.reload
    user1.user_emails.find_by_email(test_email).should be_an_instance_of(UserEmail)
    user1.user_emails.size.should eql 2
    @account.user_emails.user_for_email(test_email).should be_an_instance_of(User)
    @account.user_emails.user_for_email(case_email).should be nil
  end

  it "should delete a primary email" do
    user1 = add_user_with_multiple_emails(@account, 1)
    test_email = Faker::Internet.email
    case_email = user1.user_emails.last.email
    del_email = user1.email
    put :update, :id => user1.id, :user=>{:name => user1.name, :user_emails_attributes => {
                                                        "0" => { "email"=>user1.email, "_destroy"=>"1", "id" => user1.primary_email.id, "primary_role" => "1"}, 
                                                        "1" => { "email"=>user1.user_emails.last.email, "_destroy"=>"", "id" => user1.user_emails.last.id},
                                                        "2" => { "email"=>test_email, "_destroy"=>""}
                                                      }                            
                         }
    user1.reload
    user1.user_emails.find_by_email(test_email).should be_an_instance_of(UserEmail)
    user1.user_emails.size.should eql 2
    user1.primary_email.email.should eql case_email
    user1[:email].should eql case_email
    @account.user_emails.user_for_email(test_email).should be_an_instance_of(User)
    @account.user_emails.user_for_email(del_email).should be nil
  end

  it "should delete all emails and add one" do
    user1 = add_user_with_multiple_emails(@account, 1)
    test_email = Faker::Internet.email
    case_email = user1.user_emails.last.email
    del_email = user1.email
    put :update, :id => user1.id, :user=>{:name => user1.name, :user_emails_attributes => {
                                                        "0" => { "email"=>user1.email, "_destroy"=>"1", "id" => user1.primary_email.id, "primary_role" => "1"}, 
                                                        "1" => { "email"=>user1.user_emails.last.email, "_destroy"=>"1", "id" => user1.user_emails.last.id},
                                                        "2" => { "email"=>test_email, "_destroy"=>""}
                                                      }                            
                         }
    user1.reload
    user1.user_emails.find_by_email(test_email).should be_an_instance_of(UserEmail)
    user1.user_emails.size.should eql 1
    user1.primary_email.email.should eql test_email
    user1[:email].should eql test_email
    @account.user_emails.user_for_email(test_email).should be_an_instance_of(User)
    @account.user_emails.user_for_email(case_email).should be nil
    @account.user_emails.user_for_email(del_email).should be nil
    u = @account.user_emails.user_for_email(test_email)
    Delayed::Job.last.handler.should include(u.name)
    Delayed::Job.last.handler.should include("deliver_user_activation")
  end

  it "should delete all emails and add phone" do
    user1 = add_user_with_multiple_emails(@account, 1)
    case_email = user1.user_emails.last.email
    del_email = user1.email
    put :update, :id => user1.id, :user=>{:name => user1.name, :phone => "9872189712931893182", :user_emails_attributes => {
                                                        "0" => { "email"=>user1.email, "_destroy"=>"1", "id" => user1.primary_email.id, "primary_role" => "1"}, 
                                                        "1" => { "email"=>user1.user_emails.last.email, "_destroy"=>"1", "id" => user1.user_emails.last.id}
                                                      }                            
                         }
    user1.reload
    user1.user_emails.size.should eql 0
    user1[:email].should eql nil
    @account.users.find_by_phone("9872189712931893182").should be_an_instance_of(User)
    @account.user_emails.user_for_email(case_email).should be nil
    @account.user_emails.user_for_email(del_email).should be nil
  end

  it "should delete all emails and add no other details" do
    user1 = add_user_with_multiple_emails(@account, 1)
    case_email = user1.user_emails.last.email
    del_email = user1.email
    put :update, :id => user1.id, :user=>{:name => user1.name, :user_emails_attributes => {
                                                        "0" => { "email"=>user1.email, "_destroy"=>"1", "id" => user1.primary_email.id, "primary_role" => "1"}, 
                                                        "1" => { "email"=>user1.user_emails.last.email, "_destroy"=>"1", "id" => user1.user_emails.last.id}
                                                      }                            
                         }
    user1.reload
    response.body.should =~ /Please enter at least one contact detail/
    user1.user_emails.size.should eql 2
    user1[:email].should eql del_email
    @account.user_emails.user_for_email(case_email).should be_an_instance_of(User)
    @account.user_emails.user_for_email(del_email).should be_an_instance_of(User)
  end

  it "should verify email" do
    Delayed::Job.delete_all
    u = add_user_with_multiple_emails(@account, 3)
    u.active = true
    u.save
    u.reload
    get :verify_email, :email_id => u.user_emails.last.id, :format => 'js'
    Delayed::Job.last.handler.should include("deliver_email_activation")
    response.body.should =~ /Activation mail sent/
  end

end