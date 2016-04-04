require 'spec_helper'

describe Helpdesk::ScenarioAutomationsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @group1=create_group(@account, {:name => "Scenario"})
    @group2=create_group(@account, {:name => "Automation"})
    @test_scn=create_scn_automation_rule({ :account_id => @account.id,
                                          :accessible_attributes => {:access_type=>Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
                                          }})
    @group_scn=create_scn_automation_rule({ :account_id => @account.id,
                                          :accessible_attributes => {:access_type=>Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:groups],:group_ids=>[@group1.id]
                                          }})
    @personal_scn_test=create_scn_automation_rule({ :account_id => @account.id,
                                          :accessible_attributes => {:access_type=>Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users],:user_ids=>[@agent.id]
                                          }})
  end

  before(:each) do
    login_admin
  end

  after(:all) do
    @test_scn.destroy
    @personal_scn_test.destroy
    @group_scn.destroy
  end

  it "should go to the index page" do
    get 'index'
    response.should render_template "helpdesk/scenario_automations/index"
    response.body.should =~ /Scenario Automations/
  end

  it "should go to new scenario" do
    get 'new'
    response.should render_template "helpdesk/scenario_automations/new"
    response.body.should =~ /New Scenario/
  end

  it "should create a new scenario" do
    scn_name = "created by #{Faker::Name.name}"
    post :create, {:va_rule =>{"name"=>scn_name, "description"=>Faker::Lorem.sentence(3),:accessible_attributes => {:access_type=>Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]}},
                   :action_data => [{:name=> "ticket_type", :value=> "Question"}].to_json,
                   :name =>"ticket_type",
                   :value=>"Question"}
    scn=@account.scn_automations.find_by_name(scn_name)
    scn.should_not be_nil
    scn.accessible.should_not be_nil
  end

  it "should edit selected scenario" do
    get :edit, :id =>@test_scn.id
    response.should render_template "helpdesk/scenario_automations/edit"
  end

  it "should clone a selected scenario" do
    get :clone_rule, :id => @test_scn.id
    response.should render_template "helpdesk/scenario_automations/clone_rule"
    assigns(:va_rule).action_data.should be_eql(@test_scn.action_data)
    assigns(:va_rule).filter_data.should be_eql(@test_scn.filter_data)
    assigns(:va_rule).accessible.access_type.should be_eql(@test_scn.accessible.access_type)
  end

  it "should update a scenario" do
    put :update, {:va_rule=>{"name"=>"move to Support", "description"=>Faker::Lorem.sentence(3),
                           :accessible_attributes => {:access_type=>Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]}},
                  :action_data=>[{:name=>"priority", :value=>"3"},{:name=>"status", :value=>"3"}].to_json,  :name=>"status", :value=>"3",:id=>@test_scn.id}
    @account.scn_automations.find_by_id(@test_scn.id).action_data.should_not be_eql(@test_scn.action_data)
  end

  # validation on edit scenario - (case changes in scenario name)

  it "should update scenario name with case changes in letters" do
    put :update, {:va_rule=>{"name"=>"Move To Support", "description"=>Faker::Lorem.sentence(3),
                           :accessible_attributes => {:access_type=>Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]}},
                  :action_data=>[{:name=>"priority", :value=>"3"},{:name=>"status", :value=>"3"}].to_json,  :name=>"status", :value=>"3",:id=>@test_scn.id}
    @account.scn_automations.find_by_id(@test_scn.id).name.should be_eql("Move To Support")
  end



  it "should delete a scenario" do
    delete_scn=create_scn_automation_rule({:account_id=>@account.id,:accessible_attributes => {:access_type=>Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]}})
    delete :destroy, {:id=>delete_scn.id}
    @account.scn_automations.find_by_id(delete_scn.id).should be_nil
  end

  # create personal scenario
  it "should create personal scenario" do
    scn_name = "created by #{Faker::Name.name}"
    post :create, {:va_rule =>{"name"=>scn_name, "description"=>Faker::Lorem.sentence(3),:accessible_attributes => {:access_type=>Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users],:user_ids=>[@agent.id]}},
                   :action_data => [{:name=> "ticket_type", :value=> "Question"}].to_json,
                   :name =>"ticket_type",
                   :value=>"Question"}
    scn=@account.scn_automations.find_by_name(scn_name)
    scn.should_not be_nil
    scn.accessible.users.should_not be_nil
  end

  #shared scenarios validation
  it "should not create shared scenrio with existed name" do
    post :create, {:va_rule =>{"name"=>@group_scn.name, "description"=>Faker::Lorem.sentence(3),
                   :accessible_attributes => {:access_type=>Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
                   }},
                   :action_data => [{:name=> "ticket_type", :value=> "Question"}].to_json,
                   :name =>"ticket_type",
                   :value=>"Question"}
    scn=@account.scn_automations.find_by_name(@group_scn.name)
    scn.id.should be_eql @group_scn.id
    scn.accessible.access_type.should_not be_eql Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
  end

  # personal scenario validation
  it "should create shared scenrio with existed name" do
    post :create, {:va_rule =>{"name"=>@personal_scn_test.name, "description"=>Faker::Lorem.sentence(3),
                   :accessible_attributes => {:access_type=>Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]
                  }},
                   :action_data => [{:name=> "ticket_type", :value=> "Question"}].to_json,
                   :name =>"ticket_type",
                   :value=>"Question"}
    scn=@account.scn_automations.find_by_name(@personal_scn_test.name)
    scn.should_not be_nil
    scn.accessible.should_not be_nil
    scn.accessible.users.should_not be_nil
  end


  # multiple group access

  it "should multiple group access for scenario" do
    scn_name = "created by #{Faker::Name.name}"
    post :create, {:va_rule =>{"name"=>scn_name, "description"=>Faker::Lorem.sentence(3),
                   :accessible_attributes => {:access_type=>Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users],
                   :group_ids=>[@group1.id,@group2.id]}},
                   :action_data => [{:name=> "ticket_type", :value=> "Question"}].to_json,
                   :name =>"ticket_type",
                   :value=>"Question"}
    scn=@account.scn_automations.find_by_name(scn_name)
    scn.should_not be_nil
    scn.accessible.groups.should_not be_nil
    scn.accessible.groups.map{|group| group.id}.should eql [@group1.id,@group2.id]
  end

  # all to groups
  it "should add group access to scenario" do
    put :update, {:va_rule=>{"name"=>@test_scn.name, "description"=>Faker::Lorem.sentence(3),
                           :accessible_attributes => {:access_type=>Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:groups],:group_ids=>[@group1.id]}},
                  :action_data=>[{:name=>"priority", :value=>"3"},{:name=>"status", :value=>"3"}].to_json,  :name=>"status", :value=>"3",:id=>@test_scn.id}
    scn=@account.scn_automations.find_by_id(@test_scn.id)
    scn.action_data.should_not be_eql(@test_scn.action_data)
    scn.accessible.access_type.should eql Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:groups]
    scn.accessible.groups.map{|group| group.id}.should eql [@group1.id]
  end

  # only_me to groups
  it "should update group access to scenario" do
    put :update, {:va_rule=>{"name"=>@personal_scn_test.name, "description"=>Faker::Lorem.sentence(3),
                           :accessible_attributes => {:access_type=>Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:groups],:group_ids=>[@group1.id]}},
                  :action_data=>[{:name=>"priority", :value=>"3"},{:name=>"status", :value=>"3"}].to_json,  :name=>"status", :value=>"3",:id=>@personal_scn_test.id}
    scn=@account.scn_automations.find_by_id(@personal_scn_test.id)
    scn.accessible.access_type.should eql Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:groups]
    scn.accessible.users.should be_empty
    scn.accessible.groups.map{|group| group.id}.should eql [@group1.id]
  end

   # groups to only_me
  it "should update user access to scenario" do
    put :update, {:va_rule=>{"name"=>@group_scn.name, "description"=>Faker::Lorem.sentence(3),
                           :accessible_attributes => {:access_type=>Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]}},
                  :action_data=>[{:name=>"priority", :value=>"3"},{:name=>"status", :value=>"3"}].to_json,  :name=>"status", :value=>"3",:id=>@group_scn.id}
    scn=@account.scn_automations.find_by_id(@group_scn.id)
    scn.accessible.access_type.should eql Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]
    scn.accessible.groups.should be_empty
  end

end
