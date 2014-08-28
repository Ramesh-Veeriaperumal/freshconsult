require 'spec_helper'

describe AgentsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    RSpec.configuration.account.make_current
    @role_id = ["#{RSpec.configuration.account.roles.first.id}"]
    @agent_role = RSpec.configuration.account.roles.find_by_name("Agent")
  end

  before(:each) do
    log_in(RSpec.configuration.agent)
    stub_s3_writes
    # Delayed::Job.destroy_all
  end

  it "should render new agent template" do
    get :new
    response.body.should =~ /Agent information/
  end

  it "should create a new agent" do    
    RSpec.configuration.account.subscription.update_attributes(:state => "trial", :agent_limit => nil)
    @request.env['HTTP_REFERER'] = 'sessions/new'
    test_email = Faker::Internet.email
    post :create, { :agent => { :occasional => "false",
                                :scoreboard_level_id => "1",
                                :signature_html=> "Cheers!",
                                :user_id => "",
                                :ticket_permission => "1"
                                },
                    :user => { :helpdesk_agent => true,
                                :name => Faker::Name.name,
                                :user_emails_attributes => {"0" => {:email => test_email}},
                                :time_zone => "Chennai",
                                :job_title =>"Support Agent",
                                :phone => Faker::PhoneNumber.phone_number,
                                :language => "en",
                                :role_ids => ["#{@agent_role.id}"],
                                :privileges => @agent_role.privileges,
                                :roleValidate => ""
                              }
                  }
    created_user = RSpec.configuration.account.user_emails.user_for_email(test_email)
    created_user.should be_an_instance_of(User)
    created_user.agent.should be_an_instance_of(Agent)
    # Delayed::Job.last.handler.should include("A new agent was added in your helpdesk")
  end

  it "should not create a new agent more than the subscriped agent limit" do
    RSpec.configuration.account.subscription.update_attributes(:state => "active", :agent_limit => RSpec.configuration.account.full_time_agents.count)
    @request.env['HTTP_REFERER'] = 'sessions/new'
    test_email = Faker::Internet.email
    post :create, { :agent => { :occasional => "false",
                                :scoreboard_level_id => "1",
                                :signature_html=> "Cheers!",
                                :user_id => "",
                                :ticket_permission => "1"
                                },
                    :user => { :helpdesk_agent => true,
                                :name => Faker::Name.name,
                                :user_emails_attributes => {"0" => {:email => test_email}},
                                :time_zone => "Chennai",
                                :job_title =>"Support Agent",
                                :phone => Faker::PhoneNumber.phone_number,
                                :language => "en",
                                :role_ids => ["#{@agent_role.id}"],
                                :privileges => @agent_role.privileges,
                                :roleValidate => ""
                              }
                  }
    created_user = RSpec.configuration.account.users.find_by_email(test_email)
    created_user.should be_nil
    session[:flash][:notice].should eql "You have reached the maximum number of agents your subscription allows. You need to delete an existing agent or contact your account administrator to purchase additional agents. "
    RSpec.configuration.account.subscription.update_attributes(:state => "trial", :agent_limit => nil)
  end

  it "should not create a new agent without a Agent role or existing email ID" do
    RSpec.configuration.account.subscription.update_attributes(:state => "trial", :agent_limit => nil)
    @request.env['HTTP_REFERER'] = 'sessions/new'
    user = add_new_user(RSpec.configuration.account)
    test_name = Faker::Name.name
    post :create, { :agent => { :occasional => "false",
                                :scoreboard_level_id => "1",
                                :signature_html=> "Cheers!",
                                :user_id => "",
                                :ticket_permission => "1"
                                },
                    :user => { :helpdesk_agent => true,
                                :name => test_name,
                                :user_emails_attributes => {"0" => {:email => user.email}},
                                :time_zone => "Chennai",
                                :job_title =>"Support Agent",
                                :phone => Faker::PhoneNumber.phone_number,
                                :language => "en",
                                :role_ids => [""],
                                :privileges => "",
                                :roleValidate => ""
                              }
                  }
    response.body.should =~ /Email has already been taken/
    response.body.should =~ /A user must be associated with atleast one role/
    created_user = RSpec.configuration.account.users.find_by_name(test_name)
    created_user.should_not be_an_instance_of(User)
  end

  it "should list all the created agents in the index page" do
     user = add_agent(RSpec.configuration.account, { :name => "1#{Faker::Name.name}",
                                  :email => Faker::Internet.email,
                                  :active => 1,
                                  :agent => 1,
                                  :role => 1,
                                  :agent => 1,
                                  :ticket_permission => 3,
                                  :role_ids => ["#{@agent_role.id}"],
                                  :privileges => @agent_role.privileges })
    get :index
    response.body.should =~ /#{user.email}/
  end

  it "should show all the agent details on the show page" do
    get :show, :id => RSpec.configuration.agent.agent.id
    response.body.should =~ /#{RSpec.configuration.agent.email}/
    response.body.should =~ /Agent information/
  end

  it "should edit an existing agent" do
    user = add_test_agent(RSpec.configuration.account)
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
                                              :time_zone => user.time_zone,
                                              :language => user.language
                                            }
    edited_user = RSpec.configuration.account.user_emails.user_for_email(user.email)
    edited_user.should be_an_instance_of(User)
    edited_user.agent.ticket_permission.should be_eql(2)
  end

  it "should check_agent_limit for update" do
    RSpec.configuration.account.subscription.update_attributes(:state => "active", :agent_limit => RSpec.configuration.account.full_time_agents.count)
    user = add_test_agent(RSpec.configuration.account)
    agent = user.agent
    agent.occasional = true
    agent.save
    get :edit, :id => agent.id
    response.body.should =~ /Edit Agent/
    put :update, :id => agent.id, :agent => { :occasional => true,
                                              :scoreboard_level_id => agent.scoreboard_level_id,
                                              :ticket_permission => 2
                                            },
                                   :user => { :helpdesk_agent => true,
                                              :name => "upadate: check limit",
                                              :time_zone => user.time_zone,
                                              :language => user.language
                                            }
    user.reload
    user.should be_an_instance_of(User)
    user.name.should be_eql "upadate: check limit"
    user.agent.occasional.should be_truthy
    user.agent.ticket_permission.should be_eql(2)
    RSpec.configuration.account.subscription.update_attributes(:state => "trial", :agent_limit => nil)
  end

  it "should not update an agent when user_id is nil" do
    user = add_test_agent(RSpec.configuration.account)
    agent = user.agent
    get :edit, :id => agent.id
    response.body.should =~ /Edit Agent/
    put :update, :id => agent.id, :agent => { :occasional => agent.occasional,
                                              :scoreboard_level_id => "1",
                                              :ticket_permission => 3,
                                              :user_id => nil
                                            },
                                   :user => { :helpdesk_agent => true,
                                              :name => "",
                                              :email => "",
                                              :time_zone => user.time_zone,
                                              :language => user.language
                                            }
    user.reload
    agent.reload
    agent.should be_an_instance_of(Agent)
    agent.scoreboard_level_id.should_not be_eql(1)
    agent.ticket_permission.should_not be_eql(3)
  end

  it "should not update an user without name" do
    user = add_test_agent(RSpec.configuration.account)
    agent = user.agent
    get :edit, :id => agent.id
    response.body.should =~ /Edit Agent/
    put :update, :id => agent.id, :agent => { :occasional => agent.occasional,
                                              :scoreboard_level_id => agent.scoreboard_level_id,
                                              :ticket_permission => 1
                                            },
                                   :user => { :helpdesk_agent => true,
                                              :name => "",
                                              :email => "",
                                              :time_zone => user.time_zone,
                                              :language => user.language
                                            }
    user.reload
    user.email.should_not be_eql ""
    user.should be_an_instance_of(User)
    user.agent.ticket_permission.should be_eql(1)
    user.agent.ticket_permission.should_not be_eql(2)
  end

  it "should restrict_current_user for edit" do
    user = add_test_agent(RSpec.configuration.account)
    user.deleted = true
    user.save
    get :edit, :id => user.agent.id
    user.reload
    response.body.should_not =~ /Edit Agent/
    session[:flash][:notice].should eql "You cannot edit this agent"
  end

  it "should restrict_current_user for update" do
    user = add_test_agent(RSpec.configuration.account)
    agent = user.agent
    user.deleted = true
    user.save
    put :update, :id => agent.id, 
                 :agent => { :occasional => agent.occasional,
                             :scoreboard_level_id => agent.scoreboard_level_id,
                             :ticket_permission => 3
                            },
                 :user => { :helpdesk_agent => true,
                            :name => Faker::Name.name,
                            :time_zone => user.time_zone,
                            :language => user.language
                           }
    user.reload
    user.should be_an_instance_of(User)
    user.agent.ticket_permission.should_not be_eql(3)
    session[:flash][:notice].should eql "You cannot edit this agent"
  end

  it "should convert a full time agent to occasional" do
    user = RSpec.configuration.account.users.find_by_email(RSpec.configuration.agent.email)
    agent = user.agent
    get :edit, :id => agent.id
    response.body.should =~ /Edit Agent/
    put :update, :id => agent.id, :agent => { :occasional => 1,
                                              :scoreboard_level_id => agent.scoreboard_level_id,
                                              :user_id => user.id,
                                              :ticket_permission => 1
                                            },
                                   :user => { :helpdesk_agent => true,
                                              :name => user.name,
                                              :email => user.email,
                                              :time_zone => user.time_zone,
                                              :language => user.language
                                            }
    edited_user = RSpec.configuration.account.users.find_by_email(user.email)
    edited_user.should be_an_instance_of(User)
    edited_user.agent.occasional.should be_eql(true)
    # Delayed::Job.last.handler.should include("#{edited_user.name} was converted to an occasional agent")
  end

  it "should convert an occasional to full time agent" do
    user = RSpec.configuration.account.users.find_by_email(RSpec.configuration.agent.email)
    agent = user.agent
    get :edit, :id => agent.id
    response.body.should =~ /Edit Agent/
    put :update, :id => agent.id, :agent => { :occasional => 0,
                                              :scoreboard_level_id => agent.scoreboard_level_id,
                                              :user_id => user.id,
                                              :ticket_permission => 1
                                            },
                                   :user => { :helpdesk_agent => true,
                                              :name => user.name,
                                              :email => user.email,
                                              :time_zone => user.time_zone,
                                              :language => user.language
                                            }
    edited_user = RSpec.configuration.account.users.find_by_email(user.email)
    edited_user.should be_an_instance_of(User)
    edited_user.agent.occasional.should be_eql(false)
    # Delayed::Job.last.handler.should include("#{edited_user.name} was converted to a full time agent")
  end

  it "should convert a full time agent to a customer" do
    new_user = add_test_agent(RSpec.configuration.account)
    @request.env['HTTP_REFERER'] = 'sessions/new'
    put :convert_to_contact, :id => new_user.agent.id
    RSpec.configuration.account.users.find(new_user.id).helpdesk_agent.should be_falsey
    RSpec.configuration.account.agents.find_by_user_id(new_user.id).should be_nil
    # Delayed::Job.last.handler.should include("#{new_user.name} was deleted")
  end

  it "should restrict_current_user to convert a full time agent to a customer" do
    user = add_test_agent(RSpec.configuration.account)
    user.deleted = true
    user.save
    @request.env['HTTP_REFERER'] = 'sessions/new'
    put :convert_to_contact, :id => user.agent.id
    user.reload
    session[:flash][:notice].should eql "You cannot edit this agent"
  end

  it "should check_current_user to convert a full time agent to a customer" do
    user = add_test_agent(RSpec.configuration.account)
    log_in(user)
    @request.env['HTTP_REFERER'] = 'sessions/new'
    put :convert_to_contact, :id => user.agent.id
    user.reload
    user.deleted.should be_falsey
    session[:flash][:notice].should eql "You cannot edit this agent"
  end

  it "should delete an agent" do
    user = add_test_agent(RSpec.configuration.account)
    @request.env['HTTP_REFERER'] = 'sessions/new'
    delete :destroy, :id => user.agent.id
    user = RSpec.configuration.account.all_users.find(user.id)
    user.deleted.should be_truthy
    RSpec.configuration.account.agents.find_by_user_id(user.id).should be_nil
  end

  it "should restrict_current_user for destroy" do
    user = add_test_agent(RSpec.configuration.account)
    user.deleted = true
    user.save
    @request.env['HTTP_REFERER'] = 'sessions/new'
    delete :destroy, :id => user.agent.id
    user.reload
    user.deleted.should be_truthy
    session[:flash][:notice].should eql "You cannot edit this agent"
  end

  it "should check_current_user for destroy" do
    user = add_test_agent(RSpec.configuration.account)
    log_in(user)
    @request.env['HTTP_REFERER'] = 'sessions/new'
    delete :destroy, :id => user.agent.id
    user.reload
    user.deleted.should be_falsey
    session[:flash][:notice].should eql "You cannot edit this agent"
  end

  it "should delete avatar of a agent" do
    new_agent = FactoryGirl.build(:agent, :occasional => "false", 
                                      :scoreboard_level_id => "1", 
                                      :signature_html=> "Spec Cheers!", 
                                      :user_id => "",
                                      :ticket_permission => "1")
    new_user = FactoryGirl.build(:user, :avatar_attributes => { :content => fixture_file_upload('files/image4kb.png', 
                                        'image/png')},
                                    :helpdesk_agent => true,
                                    :name => "Spec test user",
                                    :email => Faker::Internet.email,
                                    :time_zone => "Chennai",
                                    :job_title =>"Spec Agent",
                                    :phone => Faker::PhoneNumber.phone_number, 
                                    :language => "en", 
                                    :delta => 1,
                                    :role_ids => ["#{@agent_role.id}"],
                                    :privileges => @agent_role.privileges,
                                    :active => 1)
    new_user.agent = new_agent
    new_user.save(validate: false)
    new_user.reload
    put :delete_avatar, :id => new_user.id
    new_user.reload
    new_user.avatar.should eql nil
    response.body.should =~ /success/
  end

  it "should reset password" do
    new_user = add_test_agent(RSpec.configuration.account)
    @request.env['HTTP_REFERER'] = 'sessions/new'
    put :reset_password, :id => new_user.agent.id
    session[:flash][:notice].should eql "A reset mail with instructions has been sent to #{new_user.email}."
    response.body.should =~ /redirected/
  end

  it "should restrict_current_user to reset password" do
    user = add_test_agent(RSpec.configuration.account)
    user.deleted = true
    user.save
    @request.env['HTTP_REFERER'] = 'sessions/new'
    put :reset_password, :id => user.agent.id
    user.reload
    session[:flash][:notice].should_not eql "A reset mail with instructions has been sent to #{user.email}."
    session[:flash][:notice].should eql "You cannot edit this agent"
  end

  it "should check_current_user to reset password" do
    user = add_test_agent(RSpec.configuration.account)
    log_in(user)
    @request.env['HTTP_REFERER'] = 'sessions/new'
    put :reset_password, :id => user.agent.id
    user.reload
    user.deleted.should be_falsey
    session[:flash][:notice].should eql "You cannot edit this agent"
  end

  it "should disable toggle_availability for an agent" do
    user = add_test_agent(RSpec.configuration.account)
    post :toggle_availability, :id => user.id, :value => "false"
    user.reload
    user.agent.available.should be_falsey
    response.should be_success
  end

  it "should enable toggle_availability for an agent" do
    user = add_test_agent(RSpec.configuration.account)
    user.agent.available = false
    user.save
    post :toggle_availability, :id => user.id, :value => "true"
    user.reload
    user.agent.available.should be_truthy
    response.should be_success
  end

  it "should enable toggle_shortcuts" do
    user = add_test_agent(RSpec.configuration.account)
    put :toggle_shortcuts, :id => user.agent.id
    user.reload
    user.text_uc01[:agent_preferences][:shortcuts_enabled].should be_falsey
  end

  it "should invite multiple agents from getting_started page" do
    invited_user_email = Faker::Internet.email
    invited_user_email_1 = Faker::Internet.email
    put :create_multiple_items, :agents_invite_email => [invited_user_email, invited_user_email_1]
    invited_user = RSpec.configuration.account.users.find_by_email(invited_user_email)
    invited_user.should be_an_instance_of(User)
    invited_user_1 = RSpec.configuration.account.users.find_by_email(invited_user_email_1)
    invited_user_1.should be_an_instance_of(User)
  end

  it "should not invite multiple agents with existing email ID" do
    user = add_test_agent(RSpec.configuration.account)
    put :create_multiple_items, :agents_invite_email => [user.email]
    response.body.should =~ /Successfully sent/
  end

  it "should info_for_node" do
    user = add_test_agent(RSpec.configuration.account)
    key = %{#{NodeConfig["rest_secret_key"]}#{RSpec.configuration.account.id}#{user.id}}
    hash = Digest::MD5.hexdigest(key)
    get :info_for_node, :user_id => user.id, :hash => hash
  end

  it "should not send info_for_node when hash is different" do
    user = add_test_agent(RSpec.configuration.account)
    get :info_for_node, :user_id => user.id, :hash => "2fe70832f759a712cfd1947aa778"
    response.body.should =~ /Access denied!/
  end
end
