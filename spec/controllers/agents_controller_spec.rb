require 'spec_helper'

describe AgentsController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account = create_test_account
    @role_id = ["#{@account.roles.first.id}"]
    @agent_role = @account.roles.find_by_name("Agent")
    @user = add_test_agent(@account)
  end

  before(:each) do
    @request.host = @account.full_domain
    @request.user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36 
                                        (KHTML, like Gecko) Chrome/32.0.1700.107 Safari/537.36"
    log_in(@user)
  end

  it "should create a new agent" do
    @account.subscription.update_attributes(:state => "trial", :agent_limit => nil)
    @request.env['HTTP_REFERER'] = 'sessions/new'
    test_email = Faker::Internet.email
    post :create, { :agent => { :occasional => "false", 
                                :scoreboard_level_id => "1", 
                                :signature_html=> "Cheers!", 
                                :user_id => "",
                                :ticket_permission => "1"
                                }, 
                    :user => { :helpdesk_agent => true, 
                                :name => "Tony", 
                                :email => test_email, 
                                :time_zone => "Chennai", 
                                :job_title =>"Support Agent", 
                                :phone => Faker::PhoneNumber.phone_number, 
                                :language => "en", 
                                :role_ids => ["#{@agent_role.id}"],
                                :privileges => @agent_role.privileges,
                                :roleValidate => ""
                              }
                  }
    created_user = @account.users.find_by_email(test_email)
    created_user.should be_an_instance_of(User)
    created_user.agent.should be_an_instance_of(Agent)
  end

  it "should list all the created agents in the index page" do
     user = add_agent(@account, { :name => "1#{Faker::Name.name}", 
                                  :email => Faker::Internet.email, 
                                  :active => 1, 
                                  :role => 1, 
                                  :agent => 1,
                                  :ticket_permission => 3,
                                  :role_ids => ["#{@agent_role.id}"],
                                  :privileges => @agent_role.privileges })
    get :index
    response.body.should =~ /#{user.email}/
  end
 
  it "should show all the agent details on the show page" do
    get :show, :id => @user.agent.id
    response.body.should =~ /#{@user.email}/
    response.body.should =~ /Agent information/
  end

  it "should edit an existing agent" do
    user = add_test_agent(@account)
    agent = user.agent
    get :edit, :id => agent.id
    response.body.should =~ /Edit Agent/
    test_email = Faker::Internet.email
    put :update, :id => agent.id, :agent => { :occasional => agent.occasional, 
                                              :scoreboard_level_id => agent.scoreboard_level_id, 
                                              :ticket_permission => 2
                                            }, 
                                   :user => { :helpdesk_agent => true, 
                                              :name => Faker::Name.name, 
                                              :email => test_email, 
                                              :time_zone => user.time_zone, 
                                              :language => user.language
                                            }
    edited_user = @account.users.find_by_email(test_email)
    edited_user.should be_an_instance_of(User)
    edited_user.agent.ticket_permission.should be_eql(2)
  end

  it "should convert a full time agent to a customer" do
    new_user = add_test_agent(@account)
    @request.env['HTTP_REFERER'] = 'sessions/new'
    put :convert_to_contact, :id => new_user.agent.id
    @account.users.find(new_user.id).helpdesk_agent.should be_false
    @account.agents.find_by_user_id(new_user.id).should be_nil
  end

  it "should delete an agent" do
    user = add_test_agent(@account)
    @request.env['HTTP_REFERER'] = 'sessions/new'
    delete :destroy, :id => user.agent.id
    user = @account.all_users.find(user.id)
    user.deleted.should be_true
    @account.agents.find_by_user_id(user.id).should be_nil
  end
end