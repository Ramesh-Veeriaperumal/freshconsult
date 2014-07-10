require 'spec_helper'

describe Admin::VaRulesController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @test_va_rule=create_dispatchr_rule({:account_id=>@account.id})
  end

  before(:each) do
    login_admin
  end

  it "should go to the index page" do
    get 'index'
    response.should render_template "admin/va_rules/index.html.erb"
  end

  it "should got to new dispatchr page" do
    get 'new'
    response.should render_template "admin/va_rules/new.html.erb"
  end

  it "should create a new dispatchr rule" do
    va_rule_name = "created by #{Faker::Name.name}"
    post :create , { :type=>"virtual_agents",
                     :va_rule =>{"name"=>va_rule_name, "description"=>Faker::Lorem.sentence(3), "match_type"=>"all"},
                     :filter_data=>[{:name=>"ticket_type", :operator=>"is", :value=>"Question"}].to_json,
                     :filter=>"end",
                     :name=>"priority",
                     :operator =>"is",
                     :value=>"1",
                     :action_data => [{:name=>"priority", :value=>"1"}].to_json}


    @account.all_va_rules.find_by_name(va_rule_name).should_not be_nil
  end

  it "should edit a dispatchr rule" do
    get :edit, :id =>@test_va_rule.id
    response.should render_template "admin/va_rules/edit.html.erb"
  end
  it "should update a dispatchr rule" do
    put :update, {:va_rule=>{"name"=>@test_va_rule.name+" - temp", "description"=>Faker::Lorem.sentence(3)},
                  :filter_data=>[{:name=>"subject", :operator=>"is", :value=>"temp"}].to_json,
                  :filter=>"end", :name=>"status", :operator=>"is", :value=>"6",
                  :action_data=>[{:name=>"status", :value=>"6"}].to_json, :id=>@test_va_rule.id}
    @account.all_va_rules.find_by_id(@test_va_rule.id).action_data.should_not be_eql(@test_va_rule.action_data)
  end

  it "should delete a dispatchr rule" do
    delete_va_rule_id = create_dispatchr_rule({:account_id => @account.id}).id
    delete :destroy, {:id=>delete_va_rule_id}
    @account.all_va_rules.find_by_id(delete_va_rule_id).should be_nil
  end

  it "should deactivate and activate a dispatchr rule" do
    va_rule = create_dispatchr_rule({:account_id => @account.id})
    put :activate_deactivate,  {:va_rule=>{:active=>"false"},:id =>va_rule.id}
    @account.all_va_rules.find_by_id(va_rule.id).active.should be_eql(false)
    put :activate_deactivate,  {:va_rule=>{:active=>"true"},:id =>va_rule.id}
    @account.all_va_rules.find_by_id(va_rule.id).active.should be_eql(true)
  end

  it "should cascade dispatchr rules" do
    @account.features.send(:cascade_dispatchr).create
    post :toggle_cascade, {:cascade_dispatcher=>"0","_"=>""}
    @account.reload
    @account.features?(:cascade_dispatchr).should be_false
  end

end
