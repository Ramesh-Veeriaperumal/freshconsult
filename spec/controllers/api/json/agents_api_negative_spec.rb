require 'spec_helper'

describe AgentsController do
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
    get :api_key, {:id => user.agent.id, :format => 'json'}
    forbidden_status?(response.status).should be true
  end

  it "should not get agent's api key if the requester canot assume identity of agent" do
    user = add_agent(@account, {:name => "1#{Faker::Name.name}",
                                 :email => Faker::Internet.email,
                                 :active => 1,
                                 :role => 1,
                                 :agent => 1,
                                 :ticket_permission => 3,
                                 :role_ids => ["#{@admin_role.id}"],
                                 :privileges => @admin_role.privileges })
    get :api_key, {:id => user.agent.id, :format => 'json'}
    forbidden_status?(response.status).should be true
  end

  def forbidden_status?(status)
    status == 403
  end

end