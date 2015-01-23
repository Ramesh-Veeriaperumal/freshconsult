require 'spec_helper'

describe AgentsController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account.make_current
    @role_id = ["#{@account.roles.first.id}"]
    @agent_role = @account.roles.find_by_name("Agent")
    @admin_role = @account.roles.find_by_name("Administrator")
  end

  before(:each) do
    http_login(@agent)
  end

  it "should not get agent's api key if the request is not ssl" do
    user = add_agent(@account, {:name => "1#{Faker::Name.name}",
                                 :email => Faker::Internet.email,
                                 :active => 1,
                                 :role => 1,
                                 :agent => 1,
                                 :ticket_permission => 3,
                                 :role_ids => ["#{@agent_role.id}"],
                                 :privileges => @agent_role.privileges })
    get :api_key, {:id => user.agent.id, :format => 'xml'}
    forbidden_status?(response.status).should be_true
  end

  it "should not get agent api key if the requester cannot assume identity of agent" do
    user = add_agent(@account, {:name => "1#{Faker::Name.name}",
                                 :email => Faker::Internet.email,
                                 :active => 1,
                                 :role => 1,
                                 :agent => 1,
                                 :ticket_permission => 3,
                                 :role_ids => ["#{@admin_role.id}"],
                                 :privileges => @admin_role.privileges })
    get :api_key, {:id => user.agent.id, :format => 'xml'}
    response.body =~ /access_denied/
  end
 
  it "should not update an logged in agent's role" do
    put :update, {:id => @agent.agent.id, :agent => {:user => {:role_ids => ["#{@agent_role.id}","#{@admin_role.id}"]},
                                              },:format => 'xml'}                                                                                               
    forbidden_status?(response.status).should be_true
  end
  
  it "should not update an logged in agent's ticket permission" do
    put :update, {:id => @agent.agent.id, :agent => {:ticket_permission => 2}, :format => 'xml'}                                                                                               
    forbidden_status?(response.status).should be_true
  end

  def forbidden_status?(status)
    status =~ /403 Forbidden/
  end

end