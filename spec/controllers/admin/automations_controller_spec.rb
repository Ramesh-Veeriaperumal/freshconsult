require 'spec_helper'

describe Admin::AutomationsController do
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
    response.should render_template "admin/automations/index.html.erb"
  end

  it "should create a new scenario" do
    get 'new'
    response.should render_template "admin/automations/new.html.erb"
    scn_name = "created by #{Faker::Name.name}"
    post :create, {:va_rule =>{"name"=>scn_name, "description"=>"description"},
                   :action_data => [{:name=> "ticket_type", :value=> "Question"}].to_json,
                   :name =>"ticket_type",
                   :value=>"Question"}
    @account.all_scn_automations.find_by_name(scn_name).should_not be_nil
  end

  it "should edit selected scenario" do
    scn_name = "created by #{Faker::Name.name}"
    post :create, {:va_rule =>{"name"=>scn_name, "description"=>"description"},
                   :action_data => [{:name=> "priority", :value=>"3"}, {:name=> "status", :value=> "3"}].to_json,
                   :name =>"ticket_type",
                   :value=>"Question"}
    edit_scn = @account.all_scn_automations.find_by_name(scn_name)
    get :edit, :id =>edit_scn.id
    response.should render_template "admin/automations/edit.html.erb"
  end

  it "should update a scenario" do
    scn_name = "created by #{Faker::Name.name}"
    post :create, {:va_rule =>{"name"=>scn_name, "description"=>"description"},
                   :action_data => [{:name => "ticket_type", :value=>"Question"}].to_json,
                   :name =>"ticket_type",
                   :value=>"Question"}
    edit_scn = @account.all_scn_automations.find_by_name(scn_name)
    put :update, {:va_rule=>{"name"=>"move to Support", "description"=>"rr"},
                  :action_data=>[{:name=>"priority", :value=>"3"},{:name=>"status", :value=>"3"}].to_json,  :name=>"status", :value=>"3",:id=>edit_scn.id}
    @account.all_scn_automations.find_by_id(edit_scn.id).action_data.should_not be_eql(edit_scn.action_data)
  end

  it "should delete a scenario" do
    scn_name = "created by #{Faker::Name.name}"
    post :create, {:va_rule =>{"name"=>scn_name, "description"=>"description"},
                   :action_data => [{:name=>"ticket_type", :value=>"Question"}].to_json,
                   :name =>"ticket_type",
                   :value=>"Question"}
    delete_scn_id = @account.all_scn_automations.find_by_name(scn_name).id
    delete :destroy, {:id=>delete_scn_id}
    @account.all_scn_automations.find_by_id(delete_scn_id).should be_nil
  end

end
