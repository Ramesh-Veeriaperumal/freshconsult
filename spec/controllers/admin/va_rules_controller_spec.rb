require 'spec_helper'

describe Admin::VaRulesController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account = create_test_account
    @user = add_test_agent(@account)
    @group_name = "Tickets - #{Time.now}"
    @test_ticket = create_ticket({ :status => 2 }, create_group(@account, {:name => @group_name}))
    @group = @account.groups.find_by_name(@group_name)
    @test_group = create_group(@account, {:name => "Group-Bulk -Test #{Time.now}"})
  end

  before(:each) do
    @request.host = @account.full_domain
    @request.user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36
                                        (KHTML, like Gecko) Chrome/32.0.1700.107 Safari/537.36"
    log_in(@user)
  end

  it "should go to the index page" do
    get 'index'
    response.should render_template "admin/va_rules/index.html.erb"
  end

  it "should create a new dispatchr rule" do
    get 'new'
    response.should render_template "admin/va_rules/new.html.erb"
    va_rule_name = "created by #{Faker::Name.name}"
    post :create , { :type=>"virtual_agents",
                     :va_rule =>{"name"=>va_rule_name, "description"=>"test", "match_type"=>"all"},
                     :filter_data=>[{:name=>"ticket_type", :operator=>"is", :value=>"Question"}].to_json,
                     :filter=>"end",
                     :name=>"priority",
                     :operator =>"is",
                     :value=>"1",
                     :action_data => [{:name=>"priority", :value=>"1"}].to_json}


    @account.all_va_rules.find_by_name(va_rule_name).should_not be_nil
  end

  it "should edit a dispatchr rule" do
    va_rule_name = "created by #{Faker::Name.name}"
    post :create , { :type=>"virtual_agents",
                     :va_rule =>{"name"=>va_rule_name, "description"=>"test", "match_type"=>"all"},
                     :filter_data=>[{:name=>"ticket_type", :operator=>"is", :value=>"Question"}].to_json,
                     :filter=>"end",
                     :name=>"priority",
                     :operator =>"is",
                     :value=>"1",
                     :action_data => [{:name=>"priority", :value=>"1"}].to_json}
    edit_va_rule = @account.all_va_rules.find_by_name(va_rule_name)
    get :edit, :id =>edit_va_rule.id
    response.should render_template "admin/va_rules/edit.html.erb"
  end
  it "should update a dispatchr rule" do
    va_rule_name = "created by #{Faker::Name.name}"
    post :create , { :type=>"virtual_agents",
                     :va_rule =>{"name"=>va_rule_name, "description"=>"test", "match_type"=>"all"},
                     :filter_data=>[{:name=>"ticket_type", :operator=>"is", :value=>"Question"}].to_json,
                     :filter=>"end",
                     :name=>"priority",
                     :operator =>"is",
                     :value=>"1",
                     :action_data => [{:name=>"priority", :value=>"1"}].to_json}
    edit_va_rule = @account.all_va_rules.find_by_name(va_rule_name)
    put :update, {:va_rule=>{"name"=>va_rule_name+" - temp", "description"=>"descr"},
                  :filter_data=>[{:name=>"subject", :operator=>"is", :value=>"temp"}].to_json,
                  :filter=>"end", :name=>"status", :operator=>"is", :value=>"6",
                  :action_data=>[{:name=>"status", :value=>"6"}].to_json, :id=>edit_va_rule.id}
    @account.all_va_rules.find_by_id(edit_va_rule.id).action_data.should_not be_eql(edit_va_rule.action_data)
  end

  it "should delete a dispatchr rule" do
    va_rule_name = "created by #{Faker::Name.name}"
    post :create , { :type=>"virtual_agents",
                     :va_rule =>{"name"=>va_rule_name, "description"=>"test", "match_type"=>"all"},
                     :filter_data=>[{:name=>"ticket_type", :operator=>"is", :value=>"Question"}].to_json,
                     :filter=>"end",
                     :name=>"priority",
                     :operator =>"is",
                     :value=>"1",
                     :action_data => [{:name=>"priority", :value=>"1"}].to_json}
    delete_va_rule_id = @account.all_va_rules.find_by_name(va_rule_name).id
    delete :destroy, {:id=>delete_va_rule_id}
    @account.all_va_rules.find_by_id(delete_va_rule_id).should be_nil
  end

  it "should deactivate and activate a dispatchr rule" do
    va_rule_name = "created by #{Faker::Name.name}"
    post :create , { :type=>"virtual_agents",
                     :va_rule =>{"name"=>va_rule_name, "description"=>"test", "match_type"=>"all"},
                     :filter_data=>[{:name=>"ticket_type", :operator=>"is", :value=>"Question"}].to_json,
                     :filter=>"end",
                     :name=>"priority",
                     :operator =>"is",
                     :value=>"1",
                     :action_data => [{:name=>"priority", :value=>"1"}].to_json}
    va_rule = @account.all_va_rules.find_by_name(va_rule_name)
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
    #@account.features.cascade_dispatchr.should be_nil
  end

end
