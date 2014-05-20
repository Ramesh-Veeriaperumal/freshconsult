require 'spec_helper'

describe Admin::SupervisorRulesController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @group_name = "Tickets - #{Time.now}"
    @test_ticket = create_ticket({ :status => 2 }, create_group(@account, {:name => @group_name}))
    @group = @account.groups.find_by_name(@group_name)
    @test_group = create_group(@account, {:name => "Group-Bulk -Test #{Time.now}"})
  end

  before(:each) do
    log_in(@user)
  end

  it "should go to the index page" do
    get 'index'
    response.should render_template "admin/supervisor_rules/index.html.erb"
  end

  it "should create a new supervisor rule" do
    get 'new'
    response.should render_template "admin/supervisor_rules/new.html.erb"
    supervisor_name = "created by #{Faker::Name.name}"
    post :create , { :type=>"virtual_agents",
                     :va_rule =>{"name"=>supervisor_name, "description"=>"test", "match_type"=>"all"},
                     :filter_data=>[{:name=>"ticket_type", :operator=>"is", :value=>"Question"}].to_json,
                     :filter=>"end",
                     :name=>"priority",
                     :operator =>"is",
                     :value=>"1",
                     :action_data => [{:name=>"priority", :value=>"1"}].to_json}


    @account.all_supervisor_rules.find_by_name(supervisor_name).should_not be_nil
  end

  it "should edit a supervisor rule" do
    supervisor_name = "created by #{Faker::Name.name}"
    post :create , { :type=>"virtual_agents",
                     :va_rule =>{"name"=>supervisor_name, "description"=>"test", "match_type"=>"all"},
                     :filter_data=>[{:name=>"ticket_type", :operator=>"is", :value=>"Question"}].to_json,
                     :filter=>"end",
                     :name=>"priority",
                     :operator =>"is",
                     :value=>"1",
                     :action_data => [{:name=>"priority", :value=>"1"}].to_json}
    edit_supervisor = @account.all_supervisor_rules.find_by_name(supervisor_name)
    get :edit, :id =>edit_supervisor.id
    response.should render_template "admin/supervisor_rules/edit.html.erb"
  end

  it "should update a supervisor rule" do
    supervisor_name = "created by #{Faker::Name.name}"
    post :create , { :type=>"virtual_agents",
                     :va_rule =>{"name"=>supervisor_name, "description"=>"test", "match_type"=>"all"},
                     :filter_data=>[{:name=>"ticket_type", :operator=>"is", :value=>"Question"}].to_json,
                     :filter=>"end",
                     :name=>"priority",
                     :operator =>"is",
                     :value=>"1",
                     :action_data => [{:name=>"priority", :value=>"1"}].to_json}
    edit_supervisor = @account.all_supervisor_rules.find_by_name(supervisor_name)

    put :update, {:va_rule=>{"name"=>supervisor_name+" - temp", "description"=>"descr"},
                  :filter_data=>[{:name=>"subject", :operator=>"is", :value=>"temp"}].to_json,
                  :filter=>"end", :name=>"status", :operator=>"is", :value=>"6",
                  :action_data=>[{:name=>"status", :value=>"6"}].to_json, :id=>edit_supervisor.id}
    @account.all_supervisor_rules.find_by_id(edit_supervisor.id).action_data.should_not be_eql(edit_supervisor.action_data)
  end

  it "should delete a supervisor rule" do
    supervisor_name = "created by #{Faker::Name.name}"
    post :create , { :type=>"virtual_agents",
                     :va_rule =>{"name"=>supervisor_name, "description"=>"test", "match_type"=>"all"},
                     :filter_data=>[{:name=>"ticket_type", :operator=>"is", :value=>"Question"}].to_json,
                     :filter=>"end",
                     :name=>"priority",
                     :operator =>"is",
                     :value=>"1",
                     :action_data => [{:name=>"priority", :value=>"1"}].to_json}
    delete_supervisor_id = @account.all_supervisor_rules.find_by_name(supervisor_name).id
    delete :destroy, {:id=>delete_supervisor_id}
    @account.all_supervisor_rules.find_by_id(delete_supervisor_id).should be_nil
  end

  it "should active and deactivate supervisor rule" do
    supervisor_name = "created by #{Faker::Name.name}"
    post :create , { :type=>"virtual_agents",
                     :va_rule =>{"name"=>supervisor_name, "description"=>"test", "match_type"=>"all"},
                     :filter_data=>[{:name=>"ticket_type", :operator=>"is", :value=>"Question"}].to_json,
                     :filter=>"end",
                     :name=>"priority",
                     :operator =>"is",
                     :value=>"1",
                     :action_data => [{:name=>"priority", :value=>"1"}].to_json}
    supervisor_rule = @account.all_supervisor_rules.find_by_name(supervisor_name)
    put :activate_deactivate,  {:va_rule=>{:active=>"false"},:id =>supervisor_rule.id}
    @account.all_supervisor_rules.find_by_id(supervisor_rule.id).active.should be_eql(false)
    put :activate_deactivate,  {:va_rule=>{:active=>"true"},:id =>supervisor_rule.id}
    @account.all_supervisor_rules.find_by_id(supervisor_rule.id).active.should be_eql(true)
  end

end
