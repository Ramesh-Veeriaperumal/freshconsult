require 'spec_helper'

describe Helpdesk::SlaPoliciesController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @now = (Time.now.to_f*1000).to_i
    @agent_1 = add_test_agent(@account)
    @agent_2 = add_test_agent(@account)
    @sla_policy_1 = create_sla_policy(@agent_1)
    @sla_policy_2 = create_sla_policy(@agent_2)
  end

  before(:each) do
    log_in(@agent)
  end

  after(:all) do
    @sla_policy_1.destroy
    @sla_policy_2.destroy
  end

  it "should go to the Sla_policies index page" do
    get :index
    response.body.should =~ /SLA Policies/
    response.should be_success
  end

  it "should create a new Sla Policy" do
    get :new
    response.body.should =~ /New SLA Policy/
    response.should be_success
    post :create, { :helpdesk_sla_policy =>
        sla_policies(@agent_1.id,@agent_2.id,{:name => "Sla Policy - Test Spec", :ticket_type => "Question"}),
      :SlaDetails => sla_details
    }
    session[:flash][:notice].should eql "The SLA Policy has been created."
    sla_policy = @account.sla_policies.find_by_name("Sla Policy - Test Spec")
    sla_policy.should_not be_nil
    sla_policy.conditions[:ticket_type].should eql ["Question"]
    sla_policy.escalations[:response]["1"][:agents_id].should eql [@agent.id]
    sla_policy.escalations[:resolution]["2"][:time].should eql(1800)
    sla_Detail = @account.sla_policies.find(sla_policy.id).sla_details
    sla_details = sla_Detail.find(:first,:conditions => [ "priority = ?", 3 ])
    sla_details.resolution_time.should eql(7200)
    sla_details = sla_Detail.find(:first,:conditions => [ "priority = ?", 1 ])
    sla_details.response_time.should eql(2592000)
  end

  it "should not create a new Sla Policy without a name or conditions" do
    post :create, {  :helpdesk_sla_policy => sla_policies(@agent_1.id,@agent_2.id),
      :SlaDetails => sla_details
    }
    session[:flash][:notice].should eql "Unable to save SLA Policy"
    response.body.should =~ /New SLA Policy/
  end

    it "should edit a Sla Policy" do
        get :edit, :id => @sla_policy_1.id
        response.body.should =~ /#{@sla_policy_1.name}/
    end

  it "should update a Sla Policy" do
    ids = sla_detail_ids(@sla_policy_1)
    put :update, { :id => @sla_policy_1.id,
      :helpdesk_sla_policy => sla_policies(@agent_2.id,@agent_1.id,{:id=> @sla_policy_1.id, :name => "Updated - Sla Policy",
          :description => @sla_policy_1.description, :ticket_type => "Feature Request"}),
      :SlaDetails => sla_details(ids)
    }
    @sla_policy_1.reload
    session[:flash][:notice].should eql "The SLA Policy has been updated."
    @sla_policy_1.name.should eql "Updated - Sla Policy"
    @sla_policy_1.conditions[:ticket_type].should eql ["Feature Request"]
    @sla_policy_1.conditions[:company_id].should be_blank
    @sla_policy_1.escalations[:resolution]["1"][:agents_id].should eql [@agent_2.id]
    @sla_policy_1.escalations[:resolution]["2"][:agents_id].should eql [@agent_1.id]
    sla_details = @account.sla_policies.find(@sla_policy_1.id).sla_details.find(ids[1])
    sla_details.resolution_time.should eql(7200)
  end

  it "should not update a Sla Policy without conditions" do
    ids = sla_detail_ids(@sla_policy_1)
    put :update, { :id =>  @sla_policy_1.id,
      :helpdesk_sla_policy => sla_policies(@agent_1.id,@agent.id,{:id=> @sla_policy_1.id,
          :name => "Update Sla Policy without conditions", :description => @sla_policy_1.description}),
      :SlaDetails => sla_details(ids)
    }
    @sla_policy_1.reload
    @sla_policy_1.name.should_not eql "Update Sla Policy without conditions"
    @sla_policy_1.conditions[:ticket_type].should eql ["Feature Request"]
    @sla_policy_1.escalations[:response]["1"][:agents_id].should eql [@agent.id]
    @sla_policy_1.escalations[:resolution]["1"][:agents_id].should eql [@agent_2.id]
    @sla_policy_1.escalations[:resolution]["2"][:agents_id].should_not eql [@agent.id]
  end

  it "should deactivate a Sla Policy" do
    put :activate, :helpdesk_sla_policy => {:active => "false"}, :id => @sla_policy_1.id
    @sla_policy_1.reload
    session[:flash][:notice].should eql "The SLA Policy has been deactivated."
    @sla_policy_1.active.should be false
  end

  it "should activate a Sla Policy" do
    @sla_policy_1.reload
    put :activate, :helpdesk_sla_policy => {:active => "true"}, :id => @sla_policy_1.id
    @sla_policy_1.reload
    session[:flash][:notice].should eql "The SLA Policy has been activated."
    @sla_policy_1.active.should be true
  end

  it "should not deactivate the Default Sla Policy" do
    default_sla_policy = @account.sla_policies.find_by_is_default(1)
    put :activate, :helpdesk_sla_policy => {:active => "false"}, :id => default_sla_policy.id
    default_sla_policy.reload
    session[:flash][:notice].should eql "The SLA Policy could not be activated"
    default_sla_policy.active.should_not be false
  end

  it "should reorder the Sla_policies" do
    sla_policy_3 = @account.sla_policies.find_by_name("Sla Policy - Test Spec")
    default = @account.sla_policies.find_by_is_default(1)
    reorder_list = {
      "#{default.id}" => 1,
      "#{@sla_policy_1.id}" => 4,
      "#{@sla_policy_2.id}" => 2,
      "#{sla_policy_3.id}" => 3
    }.to_json
    put :reorder, :reorderlist => reorder_list
    sla_policy_3.reload
    sla_policy_3.position.should eql(3)
    @sla_policy_1.reload
    @sla_policy_1.position.should eql(4)
    @sla_policy_2.reload
    @sla_policy_2.position.should eql(2)
  end

  it "should delete a Sla Policy" do
    sla_policy = @account.sla_policies.find_by_name("Sla Policy - Test Spec")
    delete :destroy, :id => sla_policy.id
    sla_policy = @account.sla_policies.find_by_id(sla_policy.id)
    sla_policy.should be_nil
  end
end