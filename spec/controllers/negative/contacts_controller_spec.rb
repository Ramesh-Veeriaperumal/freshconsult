require 'spec_helper'

describe ContactsController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    login_admin
  end

  it "should not create a new contact without an email" do
    post :create, :user => { :name => Faker::Name.name, :email => "" }
    response.body.should =~ /Email is invalid/
  end

  it "should not allow to create more agents than allowed by the plan" do
    contact = Factory.build(:user)
    contact.save
    @account.subscription.update_attributes(:state => "active", :agent_limit => @account.full_time_agents.count)
    @request.env['HTTP_REFERER'] = 'sessions/new'
    put :make_agent, :id => contact.id
    @account.agents.find_by_user_id(contact.id).should be_nil
    @account.subscription.update_attributes(:state => "trial")
  end
end
