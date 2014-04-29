require 'spec_helper'

describe Admin::EmailConfigsController do
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
    @name = Faker::Name.first_name
    @domain = Faker::Internet.domain_word
    @email = "#{@name}@#{@domain}.com"
    log_in(@user)
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
    delayed_job.handler.should include("deliver_activation_instructions")
    delayed_job.handler.should include("AR:EmailConfig:#{new_email_config.id}")
  end

  it "should create an email config with custom IMAP and SMTP mailboxes" do
    mailbox_username = Faker::Internet.email
    mailbox_password = Faker::Lorem.characters(10)
    clear_sqs_messages
    post :create, { :email_config => {:name => Faker::Name.name, 
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
                                      :imap_mailbox_attributes => { :_destroy => "0", 
                                                                    :server_name => "imap.gmail.com",
                                                                    :port => "993",
                                                                    :use_ssl => "true",
                                                                    :delete_from_server => "0",
                                                                    :authentication => "plain",
                                                                    :user_name => mailbox_username,
                                                                    :password => mailbox_password,
                                                                    :folder => "inbox"
                                                                  }
                                      }
                  }
    email_config = @account.all_email_configs.find_by_reply_email(mailbox_username)
    email_config.should be_an_instance_of(EmailConfig)
    email_config.imap_mailbox.should be_an_instance_of(ImapMailbox)
    
    new_message = $sqs_mailbox.receive_message
    message_body = JSON.parse(new_message.body)
    message_body["action"].should be_eql("create")
    message_body["mailbox_attributes"]["user_name"].should be_eql(mailbox_username)
    new_message.delete
    
    email_config.smtp_mailbox.should be_an_instance_of(SmtpMailbox)
    delayed_job = Delayed::Job.last
    delayed_job.handler.should include("deliver_activation_instructions")
    delayed_job.handler.should include("AR:EmailConfig:#{email_config.id}")
  end

  it "should create an email config with only custom SMTP mailbox" do
    mailbox_username = Faker::Internet.email
    mailbox_password = Faker::Lorem.characters(10)
    post :create, { :email_config => {:name => Faker::Name.name, 
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
                                      :imap_mailbox_attributes => { :_destroy => "1" }
                                      }
                  }
    email_config = @account.all_email_configs.find_by_reply_email(mailbox_username)
    email_config.should be_an_instance_of(EmailConfig)
    email_config.imap_mailbox.should be_nil
    email_config.smtp_mailbox.should be_an_instance_of(SmtpMailbox)
    delayed_job = Delayed::Job.last
    delayed_job.handler.should include("deliver_activation_instructions")
    delayed_job.handler.should include("AR:EmailConfig:#{email_config.id}")
  end


  # Editing email configs with and without custom mailbox

  it "should edit an email config" do
    email_config = Factory.build(:email_config, :to_email => Faker::Internet.email, :reply_email => Faker::Internet.email)
    email_config.save
    put :update, {  :id => email_config.id,
                    :email_config => {:name => Faker::Name.name, 
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
    delayed_job = Delayed::Job.last
    delayed_job.handler.should include("deliver_activation_instructions")
    delayed_job.handler.should include("AR:EmailConfig:#{new_email_config.id}")
  end

  it "should edit an email config with custom IMAP and SMTP mailboxes" do
    email_config = Factory.build(:primary_email_config, :to_email => Faker::Internet.email, :reply_email => Faker::Internet.email)
    email_config.save
    imap_mailbox = Factory.build(:imap_mailbox, :email_config_id => email_config.id, :account_id => @account.id)
    imap_mailbox.save
    smtp_mailbox = Factory.build(:smtp_mailbox, :email_config_id => email_config.id, :account_id => @account.id)
    smtp_mailbox.save
    mailbox_username = Faker::Internet.email
    mailbox_password = Faker::Lorem.characters(10)
    clear_sqs_messages

    put :update, {  :id => email_config.id,
                    :email_config => {:name => Faker::Name.name, 
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
                                                                    :domain => "freshpo.com",
                                                                    :id => smtp_mailbox.id
                                                                  }, 
                                      :imap_mailbox_attributes => { :_destroy => "0", 
                                                                    :server_name => "imap.gmail.com",
                                                                    :port => "993",
                                                                    :use_ssl => "true",
                                                                    :delete_from_server => "0",
                                                                    :authentication => "plain",
                                                                    :user_name => mailbox_username,
                                                                    :password => mailbox_password,
                                                                    :folder => "inbox",
                                                                    :id => imap_mailbox.id
                                                                  }
                                      }
                  }
    email_config = @account.all_email_configs.find_by_reply_email(mailbox_username)
    email_config.should be_an_instance_of(EmailConfig)
    email_config.imap_mailbox.should be_an_instance_of(ImapMailbox)
    
    new_message = $sqs_mailbox.receive_message
    message_body = JSON.parse(new_message.body)
    message_body["action"].should be_eql("update")
    message_body["mailbox_attributes"]["user_name"].should be_eql(mailbox_username)
    new_message.delete

    email_config.smtp_mailbox.should be_an_instance_of(SmtpMailbox)
    delayed_job = Delayed::Job.last
    delayed_job.handler.should include("deliver_activation_instructions")
    delayed_job.handler.should include("AR:EmailConfig:#{email_config.id}")
  end

  it "should edit an email config with custom SMTP mailbox" do
    email_config = Factory.build(:primary_email_config, :to_email => Faker::Internet.email, :reply_email => Faker::Internet.email)
    email_config.save
    smtp_mailbox = Factory.build(:smtp_mailbox, :email_config_id => email_config.id, :account_id => @account.id)
    smtp_mailbox.save
    mailbox_username = Faker::Internet.email
    mailbox_password = Faker::Lorem.characters(10)
    put :update, {  :id => email_config.id,
                    :email_config => {:name => Faker::Name.name, 
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
                                                                    :domain => "freshpo.com",
                                                                    :id => smtp_mailbox.id
                                                                  }, 
                                      :imap_mailbox_attributes => { :_destroy => "1" }
                                      }
                  }
    email_config = @account.all_email_configs.find_by_reply_email(mailbox_username)
    email_config.should be_an_instance_of(EmailConfig)
    email_config.imap_mailbox.should be_nil

    email_config.smtp_mailbox.should be_an_instance_of(SmtpMailbox)
    email_config.smtp_mailbox.user_name.should be_eql(mailbox_username)
    delayed_job = Delayed::Job.last
    delayed_job.handler.should include("deliver_activation_instructions")
    delayed_job.handler.should include("AR:EmailConfig:#{email_config.id}")
  end

  it "should remove the configured IMAP and SMTP mailboxes when switching back to default mail server" do
    email_config = Factory.build(:primary_email_config, :to_email => Faker::Internet.email, :reply_email => Faker::Internet.email)
    email_config.save
    imap_mailbox = Factory.build(:imap_mailbox, :email_config_id => email_config.id, :account_id => @account.id)
    imap_mailbox.save
    smtp_mailbox = Factory.build(:smtp_mailbox, :email_config_id => email_config.id, :account_id => @account.id)
    smtp_mailbox.save
    clear_sqs_messages

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

    new_message = $sqs_mailbox.receive_message
    message_body = JSON.parse(new_message.body)
    message_body["action"].should be_eql("delete")
    new_message.delete

    email_config.smtp_mailbox.should be_nil
  end

  it "should remove the configured SMTP mailbox when switching back to default mail server" do
    email_config = Factory.build(:email_config, :to_email => Faker::Internet.email, :reply_email => Faker::Internet.email)
    email_config.save
    smtp_mailbox = Factory.build(:smtp_mailbox, :email_config_id => email_config.id, :account_id => @account.id)
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
                                      :imap_mailbox_attributes => { :_destroy => "1" }
                                      }
                  }
    email_config = @account.all_email_configs.find_by_reply_email(email_config.reply_email)
    email_config.should be_an_instance_of(EmailConfig)
    email_config.smtp_mailbox.should be_nil
  end


  # Deleting email configs with and without custom mailbox

  it "should delete a non-primary email config without custom mailbox" do
    email_config = Factory.build(:email_config, :to_email => Faker::Internet.email, :reply_email => Faker::Internet.email)
    email_config.save!
    delete :destroy, :id => email_config.id
    @account.all_email_configs.find_by_reply_email(email_config.reply_email).should be_nil
  end

  it "should delete a non-primary email config with custom mailbox" do
    email_config = Factory.build(:email_config, :to_email => Faker::Internet.email, :reply_email => Faker::Internet.email)
    email_config.save!
    imap_mailbox = Factory.build(:imap_mailbox, :email_config_id => email_config.id, :account_id => @account.id)
    imap_mailbox.save
    smtp_mailbox = Factory.build(:smtp_mailbox, :email_config_id => email_config.id, :account_id => @account.id)
    smtp_mailbox.save
    delete :destroy, :id => email_config.id
    @account.all_email_configs.find_by_reply_email(email_config.reply_email).should be_nil
    email_config.imap_mailbox.should be_nil
    email_config.smtp_mailbox.should be_nil
  end

  def clear_sqs_messages
    $sqs_mailbox.approximate_number_of_messages.times do
      old_messages = $sqs_mailbox.receive_message
      old_messages.delete if old_messages
    end
  end
end