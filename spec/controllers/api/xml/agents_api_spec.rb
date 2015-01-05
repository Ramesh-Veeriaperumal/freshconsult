require 'spec_helper'

describe AgentsController do
  # integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account.make_current
    @role_id = ["#{@account.roles.first.id}"]
    @agent_role = @account.roles.find_by_name("Agent")
  end

  before(:each) do
    http_login(@agent)
  end

  it "should list all the created agents in the index page" do
     user = add_agent(@account, { :name => "1#{Faker::Name.name}",
                                  :email => Faker::Internet.email,
                                  :active => 1,
                                  :agent => 1,
                                  :role => 1,
                                  :agent => 1,
                                  :ticket_permission => 3,
                                  :role_ids => ["#{@agent_role.id}"],
                                  :privileges => @agent_role.privileges })
    get :index, :format => 'xml'
    result = parse_xml(response)
    expected = (response.status == 200) && (compare(result["agents"].first.keys,APIHelper::AGENT_ATTRIBS,{}).empty?) && 
          (compare(result["agents"].first["user"].keys,APIHelper::USER_ATTRIBS,{}).empty?)
    expected.should be(true)
    response.body.should =~ /#{user.email}/
  end

  it "should show all the agent details on the show page" do
    get :show, :id => @agent.agent.id, :format => 'xml'
    result = parse_xml(response)
    expected = (response.status == 200) && (compare(result["agent"].keys,APIHelper::AGENT_ATTRIBS,{}).empty?) && 
                (compare(result["agent"]["user"].keys,APIHelper::USER_ATTRIBS,{}).empty?)
    expected.should be(true)
  end

  it "should show agents filtered by email" do
    user = add_agent(@account, { :name => "1#{Faker::Name.name}",
                                 :email => Faker::Internet.email,
                                 :active => 1,
                                 :role => 1,
                                 :agent => 1,
                                 :ticket_permission => 3,
                                 :role_ids => ["#{@agent_role.id}"],
                                 :privileges => @agent_role.privileges })
    check_email  = user.email
    get :index, {:query=>"email is #{check_email}", :format => 'xml'}
    result = parse_xml(response)
    expected = (response.status == "200 OK") && (compare(result["agents"].first.keys, APIHelper::AGENT_ATTRIBS,{}).empty?) && 
          (compare(result["agents"].first["user"].keys,APIHelper::USER_ATTRIBS,{}).empty?)
    expected.should be(true)
    expected_email = result["agents"].first["user"]["email"]
    expected_email.should =~ /#{check_email}/
  end

end