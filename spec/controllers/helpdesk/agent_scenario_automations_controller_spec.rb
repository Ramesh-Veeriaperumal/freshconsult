require 'spec_helper'

describe Helpdesk::ScenarioAutomationsController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
  	@now = (Time.now.to_f*1000).to_i
  	@test_role = create_role({:name => "Second: New role test #{@now}",
                              :privilege_list => ["manage_tickets", "edit_ticket_properties", "view_solutions", "manage_solutions",
                                                  "view_forums", "0", "0", "0", "0",
                                                  "", "0", "0", "0", "0"]} )
    @new_agent = add_test_agent(@account,{:role => @test_role.id})
    @new_agent.make_current
    @test_scn=create_scn_automation_rule({ :account_id => @account.id,
                                          :accessible_attributes => {:access_type=>Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users],:user_ids=>[@new_agent.id]
                                          }})
  end

  before(:each) do
    log_in(@new_agent)
  end

  it "should go to the index page" do
    get 'index'
    response.should render_template "helpdesk/scenario_automations/index.html.erb"
    response.body.should =~ /Scenario Automations/
  end

  it "should go to new scenario" do
    get 'new'
    response.should render_template "helpdesk/scenario_automations/new.html.erb"
    response.body.should =~ /New Scenario/
  end

  it "should create a new personal scenario with other accesses" do
    scn_name = "created by #{Faker::Name.name}"
    post :create, {:va_rule =>{"name"=>scn_name, "description"=>Faker::Lorem.sentence(3),:accessible_attributes => {:access_type=>Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]}},
                   :action_data => [{:name=> "ticket_type", :value=> "Question"}].to_json,
                   :name =>"ticket_type",
                   :value=>"Question"}
    scn=@account.scn_automations.find_by_name(scn_name)
    scn.should_not be_nil
    scn.accessible.access_type.should be_eql Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]
  end

  it "should edit selected scenario" do
    get :edit, :id =>@test_scn.id
    response.should render_template "helpdesk/scenario_automations/edit.html.erb"
  end

  it "should clone a selected scenario" do
    get :clone_rule, :id => @test_scn.id
    response.should render_template "helpdesk/scenario_automations/clone_rule.html.erb"
    (@test_scn.action_data == assigns(:va_rule).action_data).should be_true
    (@test_scn.filter_data == assigns(:va_rule).filter_data).should be_true
    (@test_scn.accessible.access_type == assigns(:va_rule).accessible.access_type).should be_true
  end

  it "should update a scenario" do
    put :update, {:va_rule=>{"name"=>"move to Support", "description"=>Faker::Lorem.sentence(3),
                           :accessible_attributes => {:access_type=>Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]}},
                  :action_data=>[{:name=>"priority", :value=>"3"},{:name=>"status", :value=>"3"}].to_json,  :name=>"status", :value=>"3",:id=>@test_scn.id}
    scn=@account.scn_automations.find_by_id(@test_scn.id)
    scn.action_data.should_not be_eql(@test_scn.action_data)
    scn.accessible.access_type.should be_eql Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]
  end

  it "should delete a scenario" do
    delete_scn=create_scn_automation_rule({:account_id=>@account.id,:accessible_attributes => {:access_type=>Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users],:user_ids=>[@new_agent.id]}})
    delete :destroy, {:id=>delete_scn.id}
    @account.scn_automations.find_by_id(delete_scn.id).should be_nil
  end

  it "should create a new scenario" do
  	scn_name="Scenrio test"
    post :create, {:va_rule =>{"name"=>scn_name, "description"=>Faker::Lorem.sentence(3),
                   :accessible_attributes => {:access_type=>Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]
                  }},
                   :action_data => [{:name=> "ticket_type", :value=> "Question"}].to_json,
                   :name =>"ticket_type",
                   :value=>"Question"}
    scn=@account.scn_automations.find_by_name(scn_name)
    scn.should_not be_nil
    scn.accessible.should_not be_nil
    scn.accessible.users.should_not be_nil
  end

end

