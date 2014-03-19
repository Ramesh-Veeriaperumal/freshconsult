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

  it "should not create a new contact without an email" do
    post :create, :user => { :name => Faker::Name.name, :email => "" }
    response.body.should =~ /Email should look like an email address./
  end

  it "should not allow to create more agents than allowed by the plan" do
    log_in(@user)
    contact = Factory.build(:user)
    contact.save
    @account.subscription.update_attributes(:state => "active", :agent_limit => @account.full_time_agents.count)
    @request.env['HTTP_REFERER'] = 'sessions/new'
    put :make_agent, :id => contact.id
    @account.agents.find_by_user_id(contact.id).should be_nil
    @account.subscription.update_attributes(:state => "trial")
  end
end
