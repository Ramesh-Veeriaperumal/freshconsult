require 'spec_helper'

RSpec.configure do |c|
  c.include MemcacheKeys
end

RSpec.describe GoogleSignupController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    log_in(@agent)
  end

  after(:each) do
    @account.make_current
  end

  it "should redirect to error page if domain is invalid" do
    GoogleSignupController.any_instance.stubs(:full_domain).returns(Faker::Internet.domain_word)
    get :associate_local_to_google
  end

  it "should redirect to error page if domain is invalid" do
    get :associate_local_to_google, {:user => {:name => @agent.name,
                                              :email => @agent.email,
                                              :uid => "12345678"},
                                     :account => {:google_domain => "",
                                                 :sub_domain => ""}
                                    }
  end

  it "should redirect to signup page" do
    GoogleSignupController.any_instance.stubs(:full_domain).returns(@account.full_domain)
    get :associate_google_account, {:user => {:name => @agent.name,
                                              :email => @agent.email,
                                              :uid => "12345678"},
                                     :account => {:google_domain => "freshpo.com",
                                                 :sub_domain => "freshpo"}
                                    }
  end

  it "should redirect to associate google page if email is invalid" do
    GoogleSignupController.any_instance.stubs(:full_domain).returns(@account.full_domain)
    get :associate_google_account, {:user => {:name => @agent.name,
                                              :email => Faker::Internet.email,
                                              :uid => "12345678"},
                                     :account => {:google_domain => "freshpo.com",
                                                 :sub_domain => "freshpo"}
                                    }
  end

  it "should redirect to helpdesk if association is present" do
    GoogleSignupController.any_instance.stubs(:full_domain).returns(@account.full_domain)
    get :associate_local_to_google, {:user => {:name => @agent.name,
                                              :email => @agent.email,
                                              :uid => "12345678"},
                                     :account => {:google_domain => "freshpo.com",
                                                 :sub_domain => "freshpo"}
                                    }
  end

  it "should create user session if user credentials is valid" do
    GoogleSignupController.any_instance.stubs(:full_domain).returns(@account.full_domain)
    user = add_new_user(@account)
    user.password = "test"
    user.save
    get :associate_local_to_google, {:user => {:name => user.name,
                                              :email => user.email,
                                              :uid => "12345678"},
                                     :account => {:google_domain => "freshpo.com",
                                                 :sub_domain => "freshpo"},
                                     :user_session => {:email=> user.email,
                                                       :password=>"test",
                                                       :remember_me=>"0"}
                                    }
  end

end
