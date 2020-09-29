require 'spec_helper'

describe Admin::EmailConfigsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    @name = Faker::Name.first_name
    @domain = Faker::Internet.domain_word
    @email = "#{@name}@#{@domain}.com"
    login_admin
  end

  after(:all) do
    clear_email_config
    restore_default_feature("reply_to_based_tickets")
  end

  # Creating new email configs with and without custom mailbox

  it "should create a new email config without custom mailbox" do
    get :index
    response.should render_template("admin/email_configs/index")
    post :create, { :email_config => {:name => Faker::Name.name, 
                                      :reply_email => @email, 
                                      :group_id => "", 
                                      :to_email => "#{@domain}com#{@name}@#{@account.full_domain}", 
                                      :smtp_mailbox_attributes => { :_destroy => "1",
                                                                    :server_name => "smtp.gmail.com",
                                                                    :port => "587",
                                                                    :use_ssl => "true",
                                                                    :authentication => "plain",
                                                                    :user_name => @email,
                                                                    :password => "",
                                                                    :domain => ""
                                                                  }, 
                                      :imap_mailbox_attributes => { :_destroy => "1", 
                                                                    :server_name => "imap.gmail.com",
                                                                    :port => "993",
                                                                    :use_ssl => "true",
                                                                    :delete_from_server => "0",
                                                                    :authentication => "plain",
                                                                    :user_name => @email,
                                                                    :password => "",
                                                                    :folder => "inbox"
                                                                  }
                                      }
                  }
    new_email_config = @account.all_email_configs.find_by_reply_email(@email)
    new_email_config.should be_an_instance_of(EmailConfig)
    new_email_config.imap_mailbox.should be_nil
    new_email_config.smtp_mailbox.should be_nil
    delayed_job = Delayed::Job.last
    delayed_job.handler.should include("activation_instructions")
    delayed_job.handler.should include("AR:EmailConfig:#{new_email_config.id}")
  end

  it "should validate the custom mailbox settings" do
    mailbox_username = Faker::Internet.email
    mailbox_password = Faker::Lorem.characters(10)
    Net::IMAP.any_instance.stubs(:login).returns(true)
    Net::IMAP.any_instance.stubs(:authenticate).returns(true)
    Net::SMTP.any_instance.stubs(:start).returns(true)
    ["0", "1"].each do |i|
      post :validate_mailbox_details, { :email_config => {:name => Faker::Name.name, 
                                        :reply_email => mailbox_username, 
                                        :group_id => "", 
                                        :to_email => "#{Faker::Internet.domain_word}@#{@account.full_domain}", 
                                        :smtp_mailbox_attributes => { :_destroy => "0",
                                                                      :server_name => "smtp.gmail.com",
                                                                      :port => "587",
                                                                      :use_ssl => "true",
                                                                      :authentication => "plain",
                                                                      :user_name => mailbox_username,
                                                                      :password => mailbox_password,
                                                                      :domain => "freshpo.com"
                                                                    }, 
                                        :imap_mailbox_attributes => { :_destroy => i, 
                                                                      :server_name => "imap.gmail.com",
                                                                      :port => "993",
                                                                      :use_ssl => "true",
                                                                      :delete_from_server => "0",
                                                                      :authentication => "cram-md5",
                                                                      :user_name => mailbox_username,
                                                                      :password => mailbox_password,
                                                                      :folder => "inbox"
                                                                    }
                                        }
                                      }
      result = JSON.parse(response.body)
      result["success"].should be true
      result["msg"].should be_eql("")
    end
  end

  # it "should create an email config with custom IMAP and SMTP mailboxes" do
  #   mailbox_username = Faker::Internet.email
  #   mailbox_password = Faker::Lorem.characters(10)
  #   post :create, { :email_config => {:name => Faker::Name.name, 
  #                                     :reply_email => mailbox_username, 
  #                                     :group_id => "", 
  #                                     :to_email => "#{Faker::Internet.domain_word}@#{@account.full_domain}", 
  #                                     :smtp_mailbox_attributes => { :_destroy => "0",
  #                                                                   :server_name => "smtp.gmail.com",
  #                                                                   :port => "587",
  #                                                                   :use_ssl => "true",
  #                                                                   :authentication => "plain",
  #                                                                   :user_name => mailbox_username,
  #                                                                   :password => mailbox_password,
  #                                                                   :domain => "freshpo.com"
  #                                                                 }, 
  #                                     :imap_mailbox_attributes => { :_destroy => "0", 
  #                                                                   :server_name => "imap.gmail.com",
  #                                                                   :port => "993",
  #                                                                   :use_ssl => "true",
  #                                                                   :delete_from_server => "0",
  #                                                                   :authentication => "plain",
  #                                                                   :user_name => mailbox_username,
  #                                                                   :password => mailbox_password,
  #                                                                   :folder => "inbox"
  #                                                                 }
  #                                     }
  #                 }
  #   email_config = @account.all_email_configs.find_by_reply_email(mailbox_username)
  #   email_config.should be_an_instance_of(EmailConfig)
  #   email_config.imap_mailbox.should be_an_instance_of(ImapMailbox)
  #   email_config.smtp_mailbox.should be_an_instance_of(SmtpMailbox)
  #   delayed_job = Mailbox::Job.last
  #   delayed_job.handler.should include("activation_instructions")
  #   delayed_job.handler.should include("AR:EmailConfig:#{email_config.id}")
  # end

  # it "should create an email config with only custom SMTP mailbox" do
  #   mailbox_username = Faker::Internet.email
  #   mailbox_password = Faker::Lorem.characters(10)
  #   post :create, { :email_config => {:name => Faker::Name.name, 
  #                                     :reply_email => mailbox_username, 
  #                                     :group_id => "", 
  #                                     :to_email => "#{Faker::Internet.domain_word}@#{@account.full_domain}", 
  #                                     :smtp_mailbox_attributes => { :_destroy => "0",
  #                                                                   :server_name => "smtp.gmail.com",
  #                                                                   :port => "587",
  #                                                                   :use_ssl => "true",
  #                                                                   :authentication => "plain",
  #                                                                   :user_name => mailbox_username,
  #                                                                   :password => mailbox_password,
  #                                                                   :domain => "freshpo.com"
  #                                                                 }, 
  #                                     :imap_mailbox_attributes => { :_destroy => "1" }
  #                                     }
  #                 }
  #   email_config = @account.all_email_configs.find_by_reply_email(mailbox_username)
  #   email_config.should be_an_instance_of(EmailConfig)
  #   email_config.imap_mailbox.should be_nil
  #   email_config.smtp_mailbox.should be_an_instance_of(SmtpMailbox)
  #   delayed_job = Mailbox::Job.last
  #   delayed_job.handler.should include("activation_instructions")
  #   delayed_job.handler.should include("AR:EmailConfig:#{email_config.id}")
  # end


  # # Editing email configs with and without custom mailbox

  # it "should edit an email config" do
  #   email_config = FactoryGirl.build(:email_config, :to_email => Faker::Internet.email, :reply_email => Faker::Internet.email, :account_id => @account.id )
  #   email_config.save
  #   put :update, {  :id => email_config.id,
  #                   :email_config => {:name => Faker::Name.name, 
  #                                     :reply_email => @email, 
  #                                     :group_id => "", 
  #                                     :to_email => "#{@domain}com#{@name}@#{@account.full_domain}", 
  #                                     :smtp_mailbox_attributes => { :_destroy => "1",
  #                                                                   :server_name => "smtp.gmail.com",
  #                                                                   :port => "587",
  #                                                                   :use_ssl => "true",
  #                                                                   :authentication => "plain",
  #                                                                   :user_name => @email,
  #                                                                   :password => "",
  #                                                                   :domain => ""
  #                                                                 }, 
  #                                     :imap_mailbox_attributes => { :_destroy => "1", 
  #                                                                   :server_name => "imap.gmail.com",
  #                                                                   :port => "993",
  #                                                                   :use_ssl => "true",
  #                                                                   :delete_from_server => "0",
  #                                                                   :authentication => "plain",
  #                                                                   :user_name => @email,
  #                                                                   :password => "",
  #                                                                   :folder => "inbox"
  #                                                                 }
  #                                     }
  #                 }
  #   new_email_config = @account.all_email_configs.find_by_reply_email(@email)
  #   new_email_config.should be_an_instance_of(EmailConfig)
  #   delayed_job = Mailbox::Job.last
  #   delayed_job.handler.should include("activation_instructions")
  #   delayed_job.handler.should include("AR:EmailConfig:#{new_email_config.id}")
  # end


  # it "should edit the primary email config in to a custom mailbox and verify emails are being sent" do
  #   @account.features.mailbox.create
  #   test_email = "dev-ops@freshpo.com"
  #   email_config = @account.primary_email_config
  #   imap_mailbox = FactoryGirl.build(:imap_mailbox, :email_config_id => email_config.id, :account_id => @account.id)
  #   imap_mailbox.save
  #   smtp_mailbox = FactoryGirl.build(:smtp_mailbox, :email_config_id => email_config.id, :account_id => @account.id)
  #   smtp_mailbox.save
  #   put :update, {  :id => email_config.id,
  #                   :email_config => {:name => Faker::Name.name, 
  #                                     :reply_email => test_email, 
  #                                     :group_id => "", 
  #                                     :to_email => "freshpocomdev-ops@#{@account.full_domain}", 
  #                                     :smtp_mailbox_attributes => { :_destroy => "0",
  #                                                                   :server_name => "smtp.gmail.com",
  #                                                                   :port => "587",
  #                                                                   :use_ssl => "true",
  #                                                                   :authentication => "plain",
  #                                                                   :user_name => test_email,
  #                                                                   :password => "freshstage123",
  #                                                                   :domain => "freshpo.com",
  #                                                                   :id => smtp_mailbox.id
  #                                                                 }, 
  #                                     :imap_mailbox_attributes => { :_destroy => "0", 
  #                                                                   :server_name => "imap.gmail.com",
  #                                                                   :port => "993",
  #                                                                   :use_ssl => "true",
  #                                                                   :delete_from_server => "0",
  #                                                                   :authentication => "plain",
  #                                                                   :user_name => test_email,
  #                                                                   :password => "freshstage123",
  #                                                                   :folder => "inbox",
  #                                                                   :id => imap_mailbox.id
  #                                                                 }
  #                                     }
  #                 }
  #   delayed_job = Mailbox::Job.last
  #   delayed_job.handler.should include("activation_instructions")
  #   delayed_job.handler.should include("AR:EmailConfig:#{email_config.id}")
  #   EmailConfig.find(email_config.id).update_attributes(:active => true)
  #   email_config.imap_mailbox.should be_an_instance_of(ImapMailbox)
  #   email_config.smtp_mailbox.should be_an_instance_of(SmtpMailbox)
  #   Mailbox::Job.destroy_all
  #   test_ticket = create_ticket
  #   3.times do Mailbox::Job.reserve_and_run_one_job end
  #   clear_email_config
  # end

  # it "should edit an email config with custom IMAP and SMTP mailboxes" do
  #   email_config = FactoryGirl.build(:primary_email_config, :to_email => Faker::Internet.email, :reply_email => Faker::Internet.email, :account_id => @account.id )
  #   email_config.save
  #   imap_mailbox = FactoryGirl.build(:imap_mailbox, :email_config_id => email_config.id, :account_id => @account.id)
  #   imap_mailbox.save
  #   smtp_mailbox = FactoryGirl.build(:smtp_mailbox, :email_config_id => email_config.id, :account_id => @account.id)
  #   smtp_mailbox.save
  #   mailbox_username = Faker::Internet.email
  #   mailbox_password = Faker::Lorem.characters(10)

  #   put :update, {  :id => email_config.id,
  #                   :email_config => {:name => Faker::Name.name, 
  #                                     :reply_email => mailbox_username, 
  #                                     :group_id => "", 
  #                                     :to_email => "#{Faker::Internet.domain_word}@#{@account.full_domain}", 
  #                                     :smtp_mailbox_attributes => { :_destroy => "0",
  #                                                                   :server_name => "smtp.gmail.com",
  #                                                                   :port => "587",
  #                                                                   :use_ssl => "true",
  #                                                                   :authentication => "plain",
  #                                                                   :user_name => mailbox_username,
  #                                                                   :password => mailbox_password,
  #                                                                   :domain => "freshpo.com",
  #                                                                   :id => smtp_mailbox.id
  #                                                                 }, 
  #                                     :imap_mailbox_attributes => { :_destroy => "0", 
  #                                                                   :server_name => "imap.gmail.com",
  #                                                                   :port => "993",
  #                                                                   :use_ssl => "true",
  #                                                                   :delete_from_server => "0",
  #                                                                   :authentication => "plain",
  #                                                                   :user_name => mailbox_username,
  #                                                                   :password => mailbox_password,
  #                                                                   :folder => "inbox",
  #                                                                   :id => imap_mailbox.id
  #                                                                 }
  #                                     }
  #                 }
  #   email_config = @account.all_email_configs.find_by_reply_email(mailbox_username)
  #   email_config.should be_an_instance_of(EmailConfig)
  #   email_config.imap_mailbox.should be_an_instance_of(ImapMailbox)
  #   email_config.smtp_mailbox.should be_an_instance_of(SmtpMailbox)
  #   delayed_job = Mailbox::Job.last
  #   delayed_job.handler.should include("activation_instructions")
  #   delayed_job.handler.should include("AR:EmailConfig:#{email_config.id}")
  # end

  # it "should edit an email config with custom SMTP mailbox" do
  #   email_config = FactoryGirl.build(:primary_email_config, :to_email => Faker::Internet.email, :reply_email => Faker::Internet.email, :account_id => @account.id )
  #   email_config.save
  #   smtp_mailbox = FactoryGirl.build(:smtp_mailbox, :email_config_id => email_config.id, :account_id => @account.id)
  #   smtp_mailbox.save
  #   mailbox_username = Faker::Internet.email
  #   mailbox_password = Faker::Lorem.characters(10)
  #   put :update, {  :id => email_config.id,
  #                   :email_config => {:name => Faker::Name.name, 
  #                                     :reply_email => mailbox_username, 
  #                                     :group_id => "", 
  #                                     :to_email => "#{Faker::Internet.domain_word}@#{@account.full_domain}", 
  #                                     :smtp_mailbox_attributes => { :_destroy => "0",
  #                                                                   :server_name => "smtp.gmail.com",
  #                                                                   :port => "587",
  #                                                                   :use_ssl => "true",
  #                                                                   :authentication => "plain",
  #                                                                   :user_name => mailbox_username,
  #                                                                   :password => mailbox_password,
  #                                                                   :domain => "freshpo.com",
  #                                                                   :id => smtp_mailbox.id
  #                                                                 }, 
  #                                     :imap_mailbox_attributes => { :_destroy => "1" }
  #                                     }
  #                 }
  #   email_config = @account.all_email_configs.find_by_reply_email(mailbox_username)
  #   email_config.should be_an_instance_of(EmailConfig)
  #   email_config.imap_mailbox.should be_nil

  #   email_config.smtp_mailbox.should be_an_instance_of(SmtpMailbox)
  #   email_config.smtp_mailbox.user_name.should be_eql(mailbox_username)
  #   delayed_job = Mailbox::Job.last
  #   delayed_job.handler.should include("activation_instructions")
  #   delayed_job.handler.should include("AR:EmailConfig:#{email_config.id}")
  # end

  it "should remove the configured IMAP and SMTP mailboxes when switching back to default mail server" do
    email_config = FactoryGirl.build(:primary_email_config, :to_email => Faker::Internet.email, :reply_email => Faker::Internet.email, :account_id => @account.id )
    email_config.save
    imap_mailbox = FactoryGirl.build(:imap_mailbox, :email_config_id => email_config.id, :account_id => @account.id)
    imap_mailbox.save
    smtp_mailbox = FactoryGirl.build(:smtp_mailbox, :email_config_id => email_config.id, :account_id => @account.id)
    smtp_mailbox.save

    put :update, {  :id => email_config.id,
                    :email_config => {:name => Faker::Name.name, 
                                      :reply_email => email_config.reply_email, 
                                      :group_id => "", 
                                      :to_email => "#{Faker::Internet.domain_word}@#{@account.full_domain}", 
                                      :smtp_mailbox_attributes => { :_destroy => "1",
                                                                    :server_name => "smtp.gmail.com",
                                                                    :port => "587",
                                                                    :use_ssl => "true",
                                                                    :authentication => "plain",
                                                                    :user_name => smtp_mailbox.user_name,
                                                                    :password => smtp_mailbox.password,
                                                                    :domain => "freshpo.com",
                                                                    :id => smtp_mailbox.id
                                                                  }, 
                                      :imap_mailbox_attributes => { :_destroy => "1", 
                                                                    :server_name => "imap.gmail.com",
                                                                    :port => "993",
                                                                    :use_ssl => "true",
                                                                    :delete_from_server => "0",
                                                                    :authentication => "plain",
                                                                    :user_name => imap_mailbox.user_name,
                                                                    :password => imap_mailbox.password,
                                                                    :folder => "inbox",
                                                                    :id => imap_mailbox.id
                                                                  }
                                      }
                  }
    email_config = @account.all_email_configs.find_by_reply_email(email_config.reply_email)
    email_config.should be_an_instance_of(EmailConfig)
    email_config.imap_mailbox.should be_nil
    email_config.smtp_mailbox.should be_nil
  end

  it "should remove the configured SMTP mailbox when switching back to default mail server" do
    email_config = FactoryGirl.build(:email_config, :to_email => Faker::Internet.email, :reply_email => Faker::Internet.email, :account_id => @account.id )
    email_config.save
    smtp_mailbox = FactoryGirl.build(:smtp_mailbox, :email_config_id => email_config.id, :account_id => @account.id)
    smtp_mailbox.save

    put :update, {  :id => email_config.id,
                    :email_config => {:name => Faker::Name.name, 
                                      :reply_email => email_config.reply_email, 
                                      :group_id => "", 
                                      :to_email => email_config.to_email, 
                                      :smtp_mailbox_attributes => { :_destroy => "1",
                                                                    :server_name => "smtp.gmail.com",
                                                                    :port => "587",
                                                                    :use_ssl => "true",
                                                                    :authentication => "plain",
                                                                    :user_name => smtp_mailbox.user_name,
                                                                    :password => smtp_mailbox.password,
                                                                    :domain => "freshpo.com",
                                                                    :id => smtp_mailbox.id
                                                                  }, 
                                      :imap_mailbox_attributes => { :_destroy => "1" }
                                      }
                  }
    email_config = @account.all_email_configs.find_by_reply_email(email_config.reply_email)
    email_config.should be_an_instance_of(EmailConfig)
    email_config.smtp_mailbox.should be_nil
  end


  # Deleting email configs with and without custom mailbox

  it "should delete a non-primary email config without custom mailbox" do
    email_config = FactoryGirl.build(:email_config, :to_email => Faker::Internet.email, :reply_email => Faker::Internet.email, :account_id => @account.id )
    email_config.save!
    delete :destroy, :id => email_config.id
    @account.all_email_configs.find_by_reply_email(email_config.reply_email).should be_nil
  end

  it "should delete a non-primary email config with custom mailbox" do
    email_config = FactoryGirl.build(:email_config, :to_email => Faker::Internet.email, :reply_email => Faker::Internet.email, :account_id => @account.id )
    email_config.save!
    imap_mailbox = FactoryGirl.build(:imap_mailbox, :email_config_id => email_config.id, :account_id => @account.id)
    imap_mailbox.save
    smtp_mailbox = FactoryGirl.build(:smtp_mailbox, :email_config_id => email_config.id, :account_id => @account.id)
    smtp_mailbox.save
    delete :destroy, :id => email_config.id
    @account.all_email_configs.find_by_reply_email(email_config.reply_email).should be_nil
    email_config.imap_mailbox.should be_nil
    email_config.smtp_mailbox.should be_nil
  end

  it "should get an existing email config" do
    get :existing_email, :email_address => @account.all_email_configs.last.reply_email
    JSON.parse(response.body)["success"].should eql false
  end

  it "should not get an existing email config" do
    get :existing_email, :email_address => Faker::Internet.email
    JSON.parse(response.body)["success"].should eql true
  end

  it "should initialize a new email config" do
    get :new
    response.should render_template "admin/email_configs/new"
  end

  it "should edit an existing email config" do
    get :edit, :id => @account.all_email_configs.last.id
    response.should render_template "admin/email_configs/edit"
  end

  it "should deliver test email" do
    put :test_email, :id => @account.all_email_configs.last.id
    JSON.parse(response.body)["email_sent"].should eql true
  end

  it "should make the given email_config as primary" do
    a = @account.primary_email_config.id
    email_config = FactoryGirl.build(:email_config, :to_email => Faker::Internet.email, :reply_email => Faker::Internet.email)
    email_config.account_id = @account.id
    email_config.save!
    put :make_primary, :id => @account.all_email_configs.reject{|x| x.id == a}.last.id
    @account.reload
    @account.primary_email_config.id.should_not eql a
  end

  # it "should deliver activation token" do
  #   email_config = FactoryGirl.build(:email_config, :to_email => Faker::Internet.email, :reply_email => Faker::Internet.email)
  #   email_config.account_id = @account.id
  #   email_config.save!
  #   get :deliver_verification, :id => email_config.id
  #   session[:flash][:notice].should =~ /Verification email has been sent to #{email_config.reply_email}/
  #   delayed_job = Mailbox::Job.last
  #   delayed_job.handler.should include("activation_instructions")
  #   delayed_job.handler.should include("AR:EmailConfig:#{email_config.id}")
  # end

  it "should register email" do
    email_config = FactoryGirl.build(:email_config, :to_email => Faker::Internet.email, :reply_email => Faker::Internet.email)
    email_config.account_id = @account.id
    email_config.set_activator_token
    email_config.save!
    get :register_email, :activation_code => email_config.activator_token
    email_config.reload
    email_config.active.should eql true
    session[:flash][:notice].should =~ /#{email_config.reply_email} has been activated!/
  end

  it "should not register email" do
    email_config = FactoryGirl.build(:email_config, :to_email => Faker::Internet.email, :reply_email => Faker::Internet.email)
    email_config.account_id = @account.id
    email_config.set_activator_token
    email_config.save!
    get :register_email, :activation_code => Faker::Lorem.words(4).join("-")
    email_config.reload
    email_config.active.should_not eql true
    session[:flash][:warning].should =~ /The activation code is not valid!/
  end

  it "should get already registered email" do
    email_config = @account.email_configs.first
    if email_config.activator_token.nil?
      email_config.activator_token = Digest::MD5.hexdigest(Helpdesk::SECRET_1 + email_config.reply_email + Time.now.to_f.to_s).downcase
      email_config.save(:validate => false)
      email_config.reload
    end
    get :register_email, :activation_code => email_config.activator_token
    email_config.reload
    email_config.active.should eql true
    session[:flash][:warning].should =~ /#{email_config.reply_email} has been activated already!/
  end


  it "should enable reply_to email feature" do
    post :reply_to_email_enable
    @account.reload
    @account.features?(:reply_to_based_tickets).should eql true
  end

  it "should disable reply_to email feature" do
    post :reply_to_email_disable
    @account.reload
    @account.features?(:reply_to_based_tickets).should eql false
  end

  it "should enable personalized email" do
    post :personalized_email_enable
    @account.reload
    @account.features?(:personalized_email_replies).should eql true
  end

  it "should disable personalized email" do
    post :personalized_email_disable
    @account.reload
    @account.features?(:personalized_email_replies).should eql false
  end

  it "should throw error on create" do
    to = "#{@domain}com#{@name}@#{@account.full_domain}"
    post :create, { :email_config => {:name => Faker::Name.name, 
                                      :reply_email => @account.primary_email_config.reply_email, 
                                      :group_id => "", 
                                      :to_email => to,
                                      :smtp_mailbox_attributes => { :_destroy => "1",
                                                                    :server_name => "smtp.gmail.com",
                                                                    :port => "587",
                                                                    :use_ssl => "true",
                                                                    :authentication => "plain",
                                                                    :user_name => @email,
                                                                    :password => "",
                                                                    :domain => ""
                                                                  }, 
                                      :imap_mailbox_attributes => { :_destroy => "1", 
                                                                    :server_name => "imap.gmail.com",
                                                                    :port => "993",
                                                                    :use_ssl => "true",
                                                                    :delete_from_server => "0",
                                                                    :authentication => "plain",
                                                                    :user_name => @email,
                                                                    :password => "",
                                                                    :folder => "inbox"
                                                                  }
                                      }
                  }
  new_email_config = @account.all_email_configs.find_by_to_email(to)
  new_email_config.should eql nil
  response.body.should =~ /Reply email has already been taken/
  end

  it "should throw error on update" do
    email_config = FactoryGirl.build(:email_config, :to_email => Faker::Internet.email, :reply_email => Faker::Internet.email, :account_id => @account.id )
    email_config.save
    put :update, {  :id => email_config.id,
                    :email_config => {:name => Faker::Name.name, 
                                      :reply_email => @account.primary_email_config.reply_email, 
                                      :group_id => "", 
                                      :to_email => "#{@domain}com#{@name}@#{@account.full_domain}", 
                                      :smtp_mailbox_attributes => { :_destroy => "1",
                                                                    :server_name => "smtp.gmail.com",
                                                                    :port => "587",
                                                                    :use_ssl => "true",
                                                                    :authentication => "plain",
                                                                    :user_name => @email,
                                                                    :password => "",
                                                                    :domain => ""
                                                                  }, 
                                      :imap_mailbox_attributes => { :_destroy => "1", 
                                                                    :server_name => "imap.gmail.com",
                                                                    :port => "993",
                                                                    :use_ssl => "true",
                                                                    :delete_from_server => "0",
                                                                    :authentication => "plain",
                                                                    :user_name => @email,
                                                                    :password => "",
                                                                    :folder => "inbox"
                                                                  }
                                      }
                  }
  response.body.should =~ /Reply email has already been taken/
  end

  it "should not delete primary email config" do
    delete :destroy, :id => @account.primary_email_config.id
    session[:flash][:notice] =~ /Cannot delete a primary email./
  end

end
