require 'spec_helper'

describe Admin::ObserverRulesController do
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
    response.should render_template "admin/observer_rules/index.html.erb"
  end

  it "should create a new observer rule" do
    get 'new'
    response.should render_template "admin/observer_rules/new.html.erb"
    observer_rule_name = "created by #{Faker::Name.name}"
    post :create , { :type=>"virtual_agents",
                     :va_rule =>{"name"=>observer_rule_name, "description"=>"test", "match_type"=>"all"},
                     :filter_data=>[{:name=>"ticket_type", :operator=>"is", :value=>"Problem"}].to_json,
                     :filter=>"end",
                     :operator=>"is", :value=>"2",
                     :event_data=>[{:name=>"priority", :from=>"--", :to=>"--"}].to_json,
                     :event=>"end",
                     :name=>"status", :from=>"--", :to=>"--", :performer_data=>{"type"=>"1"},
                     :action_data => [{:name=>"priority", :value=>"2"}].to_json}
    @account.all_observer_rules.find_by_name(observer_rule_name).should_not be_nil
  end

  it "should edit observer rule" do
    observer_rule_name = "created by #{Faker::Name.name}"
    post :create , { :type=>"virtual_agents",
                     :va_rule =>{"name"=>observer_rule_name, "description"=>"test", "match_type"=>"all"},
                     :filter_data=>[{:name=>"ticket_type", :operator=>"is", :value=>"Problem"}].to_json,
                     :filter=>"end",
                     :operator=>"is", :value=>"2",
                     :event_data=>[{:name=>"priority", :from=>"--", :to=>"--"}].to_json,
                     :event=>"end",
                     :name=>"status", :from=>"--", :to=>"--", :performer_data=>{"type"=>"1"},
                     :action_data => [{:name=>"priority", :value=>"2"}].to_json}
    edit_observer = @account.all_observer_rules.find_by_name(observer_rule_name)
    get :edit, :id =>edit_observer.id
    response.should render_template "admin/observer_rules/edit.html.erb"
  end
  it "should update observer rule" do
    observer_rule_name = "created by #{Faker::Name.name}"
    post :create , { :type=>"virtual_agents",
                     :va_rule =>{"name"=>observer_rule_name, "description"=>"test", "match_type"=>"all"},
                     :filter_data=>[{:name=>"ticket_type", :operator=>"is", :value=>"Problem"}].to_json,
                     :filter=>"end",
                     :operator=>"is", :value=>"2",
                     :event_data=>[{:name=>"priority", :from=>"--", :to=>"--"}].to_json,
                     :event=>"end",
                     :name=>"status", :from=>"--", :to=>"--", :performer_data=>{"type"=>"1"},
                     :action_data => [{:name=>"priority", :value=>"2"}].to_json}
    edit_observer = @account.all_observer_rules.find_by_name(observer_rule_name)

    put :update, {:va_rule=>{"name"=>observer_rule_name+" - temp", "description"=>"descr"},
                  :filter_data=>[{:name=>"subject", :operator=>"is", :value=>"temp"}].to_json,
                  :filter=>"end", :name=>"status", :operator=>"is", :value=>"6",
                  :event_data=>[{:name=>"priority", :from=>"--", :to=>"--"}].to_json,
                  :event=>"end",
                  :name=>"status", :from=>"--", :to=>"--", :performer_data=>{"type"=>"1"},
                  :action_data=>[{:name=>"status",:value=>"6"}].to_json, :id=>edit_observer.id}
    @account.all_observer_rules.find_by_id(edit_observer.id).action_data.should_not be_eql(edit_observer.action_data)
  end

  it "should delete a observer rule" do
    observer_rule_name = "created by #{Faker::Name.name}"
    post :create , { :type=>"virtual_agents",
                     :va_rule =>{"name"=>observer_rule_name, "description"=>"test", "match_type"=>"all"},
                     :filter_data=>[{:name=>"ticket_type", :operator=>"is", :value=>"Problem"}].to_json,
                     :filter=>"end",
                     :operator=>"is", :value=>"2",
                     :event_data=>[{:name=>"priority", :from=>"--", :to=>"--"}].to_json,
                     :event=>"end",
                     :name=>"status", :from=>"--", :to=>"--", :performer_data=>{"type"=>"1"},
                     :action_data => [{:name=>"priority", :value=>"2"}].to_json}
    delete_observer_id = @account.all_observer_rules.find_by_name(observer_rule_name).id
    delete :destroy, {:id=>delete_observer_id}
    @account.all_observer_rules.find_by_id(delete_observer_id).should be_nil
  end

  it "should active and deactivate a observer rule" do
    observer_rule_name = "created by #{Faker::Name.name}"
    post :create , { :type=>"virtual_agents",
                     :va_rule =>{"name"=>observer_rule_name, "description"=>"test", "match_type"=>"all"},
                     :filter_data=>[{:name=>"ticket_type", :operator=>"is", :value=>"Problem"}].to_json,
                     :filter=>"end",
                     :operator=>"is", :value=>"2",
                     :event_data=>[{:name=>"priority", :from=>"--", :to=>"--"}].to_json,
                     :event=>"end",
                     :name=>"status", :from=>"--", :to=>"--", :performer_data=>{"type"=>"1"},
                     :action_data => [{:name=>"priority",:value=>"2"}].to_json}
    observer_rule = @account.all_observer_rules.find_by_name(observer_rule_name)
    put :activate_deactivate,  {:va_rule=>{:active=>"false"},:id =>observer_rule.id}
    @account.all_observer_rules.find_by_id(observer_rule.id).active.should be_eql(false)
    put :activate_deactivate,  {:va_rule=>{:active=>"true"},:id =>observer_rule.id}
    @account.all_observer_rules.find_by_id(observer_rule.id).active.should be_eql(true)
  end

end
