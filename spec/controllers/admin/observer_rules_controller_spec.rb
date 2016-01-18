require 'spec_helper'

describe Admin::ObserverRulesController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @test_observer_rule = create_observer_rule({:account_id => @account.id})
  end

  before(:each) do
    login_admin
  end

  it "should go to the index page" do
    get 'index'
    response.should render_template "admin/observer_rules/index"
  end

  it "should go to new observer rule page" do
    get 'new'
    response.should render_template "admin/observer_rules/new"
  end

  it "should create a new observer rule" do
    observer_rule_name = "created by #{Faker::Name.name}"
    post :create , { :type=>"virtual_agents",
                     :va_rule =>{"name"=>observer_rule_name, "description"=>Faker::Lorem.sentence(3), "match_type"=>"all"},
                     :filter_data=>[{:name=>"ticket_type", :operator=>"in", :value=>["Problem", "Question"]}].to_json,
                     :filter=>"end",
                     :operator=>"is", :value=>"2",
                     :event_data=>[{:name=>"priority", :from=>"--", :to=>"--"}].to_json,
                     :event=>"end",
                     :name=>"status", :from=>"--", :to=>"--", :performer_data=>{"type"=>"1"},
                     :action_data => [{:name=>"priority", :value=>"2"}].to_json}
    @account.all_observer_rules.find_by_name(observer_rule_name).should_not be_nil
  end

  it "should edit observer rule" do
    get :edit, :id =>@test_observer_rule.id
    response.should render_template "admin/observer_rules/edit"
  end

  it "should clone a observer rule" do
    get :clone_rule, :id => @test_observer_rule.id
    response.should render_template "admin/observer_rules/clone_rule"
    (@test_observer_rule.id == assigns(:va_rule).id).should be true
    (@test_observer_rule.action_data == assigns(:va_rule).action_data).should be true
    (@test_observer_rule.filter_data == assigns(:va_rule).filter_data).should be true
  end

  it "should update observer rule" do
    put :update, {:va_rule=>{"name"=>@test_observer_rule.name+" - temp", "description"=>Faker::Lorem.sentence(3)},
                  :filter_data=>[{:name=>"subject", :operator=>"is", :value=>"temp"}].to_json,
                  :filter=>"end", :name=>"status", :operator=>"in", :value=>["6", "2"],
                  :event_data =>[{:name=>"priority", :from=>"--", :to=>"--"}].to_json,
                  :event=>"end",
                  :name=>"status", :from=>"--", :to=>"--", :performer_data=>{"type"=>"1"},
                  :action_data=>[{:name=>"status",:value=>"6"}].to_json, :id=>@test_observer_rule.id}
    @account.all_observer_rules.find_by_id(@test_observer_rule.id).action_data.should_not be_eql(@test_observer_rule.action_data)
  end

  it "should delete a observer rule" do
    delete_observer_id = create_observer_rule({:account_id => @account.id}).id
    delete :destroy, {:id=>delete_observer_id}
    @account.all_observer_rules.find_by_id(delete_observer_id).should be_nil
  end

  it "should active and deactivate a observer rule" do
    observer_rule = create_observer_rule({:account_id => @account.id})
    put :activate_deactivate,  {:va_rule=>{:active=>"false"},:id =>observer_rule.id}
    @account.all_observer_rules.find_by_id(observer_rule.id).active.should be_eql(false)
    put :activate_deactivate,  {:va_rule=>{:active=>"true"},:id =>observer_rule.id}
    @account.all_observer_rules.find_by_id(observer_rule.id).active.should be_eql(true)
  end

end
