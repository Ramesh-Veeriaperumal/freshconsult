require 'spec_helper'

describe Admin::AutomationsController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @test_scn=create_scn_automation_rule({ :account_id => @account.id })
  end

  before(:each) do
    login_admin
  end

  it "should go to the index page" do
    get 'index'
    response.should render_template "admin/automations/index.html.erb"
    response.body.should =~ /Scenario Automations/
  end

  it "should go to new scenario" do
    get 'new'
    response.should render_template "admin/automations/new.html.erb"
    response.body.should =~ /New Scenario/
  end

  it "should create a new scenario" do
    scn_name = "created by #{Faker::Name.name}"
    post :create, {:va_rule =>{"name"=>scn_name, "description"=>Faker::Lorem.sentence(3)},
                   :action_data => [{:name=> "ticket_type", :value=> "Question"}].to_json,
                   :name =>"ticket_type",
                   :value=>"Question"}
    @account.all_scn_automations.find_by_name(scn_name).should_not be_nil
  end

  it "should edit selected scenario" do
    get :edit, :id =>@test_scn.id
    response.should render_template "admin/automations/edit.html.erb"
    response.body.should =~ /Edit Scenario/
  end

  it "should update a scenario" do
    put :update, {:va_rule=>{"name"=>"move to Support", "description"=>Faker::Lorem.sentence(3)},
                  :action_data=>[{:name=>"priority", :value=>"3"},{:name=>"status", :value=>"3"}].to_json,  :name=>"status", :value=>"3",:id=>@test_scn.id}
    @account.all_scn_automations.find_by_id(@test_scn.id).action_data.should_not be_eql(@test_scn.action_data)
  end

  it "should delete a scenario" do
    delete_scn=create_scn_automation_rule({:account_id=>@account.id})
    delete :destroy, {:id=>delete_scn.id}
    @account.all_scn_automations.find_by_id(delete_scn.id).should be_nil
  end

end
