require 'spec_helper'

describe Helpdesk::DashboardController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @agent.make_current
    @forum_category = create_test_category
    @forum = create_test_forum(@forum_category)
    @id = @account.activities.last.id
    create_test_freshfone_account
  end

  before(:each) do
    login_admin
    @agent.make_current
    create_test_freshfone_account
  end

  after(:each) do
    Freshfone::User.destroy_all
  end  
  
  after(:all) do
    @account.subscription.update_attributes(:state => "trial")
  end

  it "should display the Dashboard page" do
    xhr :get, :index
    response.body.should =~ /#{@forum.name}/
    response.body.should =~ /#{@forum_category.name}/
    response.should be_success
  end

  it "should display the activity_list without id" do
    topic = create_test_topic(@forum)
    get :activity_list
    response.body.should =~ /Recent Activity/
    response.body.should =~ /#{topic.title}/
    response.body.should =~ /#{@forum.name}/
    response.body.should =~ /#{@forum_category.name}/
    response.should be_success
  end

  it "should display the activity_list with activity_id" do
    cr_folder = create_cr_folder({:name => Faker::Name.name})
    get :activity_list, :activity_id => @id
    response.body.should_not =~ /#{cr_folder.name}/
    response.body.should =~ /#{@forum_category.name}/
    response.should be_success
  end

  it "should display the latest_activities of the user" do
    new_ticket = create_ticket({:status => 2})
    get :latest_activities, :previous_id => @id
    response.body.should =~ /#{new_ticket.subject}/
    response.should be_success
  end

  it "should display the latest ticket summary" do
    get :latest_summary
    response.body.should =~ /Ticket summary/
    response.body.should =~ /Overdue/
    response.body.should =~ /Due Today/
    response.body.should =~ /On Hold/
    response.should be_success
  end

  # For covering check_account_state method in application controller
  it "should redirect to subscriptions page when the account is not active" do
    @account.subscription.update_attributes(:state => "suspended")
    get :index
    response.should be_redirect
    response.body =~ /#{@account.full_domain}\/subscription/
    @account.subscription.update_attributes(:state => "trial")
  end

  # For covering check_account_state method in application controller
  it "should access denied page when the account is inactive and non-admin agents" do
    @account.subscription.update_attributes(:state => "suspended")
    controller.class.any_instance.stubs(:privilege?).returns(false)
    get :index
    response.should be_redirect
    response.body =~ /#{@account.full_domain}\/support\/login/
    @account.subscription.update_attributes(:state => "trial")
    controller.class.any_instance.unstub(:privilege?)
  end

  # For covering handle_unverified_request method in application controller
  it "should redirect to login page when host is invalid and portal type is facebook" do
    Account.any_instance.stubs(:make_current).raises(ActiveSupport::MessageVerifier::InvalidSignature)
    ApplicationController.any_instance.stubs(:super).returns(true)
    xhr :get, :index, :portal_type => "facebook"
    response.should be_redirect
    response.body.should =~ /#{@account.full_domain}\/support\/home/
    Account.any_instance.unstub(:make_current)
    ApplicationController.any_instance.unstub(:super)
    @account.make_current
  end

  # For covering handle_unverified_request method in application controller
  it "should redirect to login page when host is invalid" do
    Account.any_instance.stubs(:make_current).raises(ActiveSupport::MessageVerifier::InvalidSignature)
    ApplicationController.any_instance.stubs(:super).returns(true)
    xhr :get, :index
    response.should be_redirect
    response.body.should =~ /#{@account.full_domain}\/support\/login/
    Account.any_instance.unstub(:make_current)
    ApplicationController.any_instance.unstub(:super)
    @account.make_current
  end


  it "should have only online freshfone agents" do
    create_dummy_freshfone_users(10,1)
    get :agent_status
    assigns[:freshfone_agents].map{|agent| agent.presence}.uniq.should be_eql([1])
    response.should be_success
  end

  it "should have only offline freshfone agents" do
    create_dummy_freshfone_users(10,0)
    get :agent_status
    assigns[:freshfone_agents].map{|agent| agent.presence}.uniq.should be_eql([0])
    response.should be_success
  end

  it "should have online and offline freshfone agents" do
    create_dummy_freshfone_users(5,0)
    create_dummy_freshfone_users(5,1)
    get :agent_status
    assigns[:freshfone_agents].map{|agent| agent.presence}.uniq.should be_eql([0,1])
    response.should be_success
  end

  it "should load freshfone agents" do
    create_dummy_freshfone_users(5,0)
    create_dummy_freshfone_users(5,1)
    get :agent_status
    response.body.should =~ /- No Agents -/
  end

  

  
end
