require 'spec_helper'

describe Admin::EmailConfigsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    login_admin
  end

  it "should not delete a primary email config" do
    email_config = FactoryGirl.build(:primary_email_config, :to_email => Faker::Internet.email, 
                                                        :reply_email => Faker::Internet.email)
    email_config.save
    delete :destroy, { :id => email_config.id }
    @account.all_email_configs.find_by_reply_email(email_config.reply_email).should be_an_instance_of(EmailConfig)
  end

  it "should validate the custom mailbox settings" do
    mailbox_username = Faker::Internet.email
    mailbox_password = Faker::Lorem.characters(10)
    ["SocketError", "Exception"].each do |exception|
      Net::IMAP.any_instance.stubs(:login).raises(exception.constantize)
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
      result = JSON.parse(response.body)
      result["success"].should be false
      result["msg"].should_not be_eql("")
      Net::IMAP.any_instance.unstub(:login)
    end
  end

  it "should validate the custom mailbox settings" do
    mailbox_username = Faker::Internet.email
    mailbox_password = Faker::Lorem.characters(10)
    Net::IMAP.any_instance.stubs(:capability).returns([])
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
    result = JSON.parse(response.body)
    result["success"].should be false
    result["msg"].should_not be_eql("")
    Net::IMAP.any_instance.unstub(:capability)
  end

  it "should validate the custom mailbox settings" do
    mailbox_username = Faker::Internet.email
    mailbox_password = Faker::Lorem.characters(10)
    ["Timeout::Error", "SocketError", "Net::SMTPAuthenticationError", "Exception"].each do |exception|
      Net::SMTP.any_instance.stubs(:start).raises(exception.constantize)
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
      result = JSON.parse(response.body)
      result["success"].should be false
      result["msg"].should_not be_eql("")
      Net::SMTP.any_instance.unstub(:start)
    end
  end
end
