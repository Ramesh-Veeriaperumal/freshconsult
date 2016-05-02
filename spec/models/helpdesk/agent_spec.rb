require 'spec_helper'

describe Agent do

  before (:all) do
  	@agent1 = add_agent_to_account(@account, {:name => "testing2", :email => Faker::Internet.email, 
                                              :active => 1, :role => 1
                                              })
  end

  it "should be available by default"  do
  	@agent2 = add_agent_to_account(@account, {:name => "testing3", :email => Faker::Internet.email, 
                                              :active => 1, :role => 1
                                              })
  	expect(@agent2.available).to be true
  end

  it "can be made unavailable" do
  	@agent1.available = 0
  	@agent1.save!
    expect(@agent1.available).to be false
  end

  it "should allow agent to toggle availability only if allowed in all groups of the agent" do
    @agent3 = add_agent_to_account(@account, {:name => "agent3", :email => Faker::Internet.email, 
                                              :active => 1, :role => 1
                                              })
    @agent4 = add_agent_to_account(@account, {:name => "agent4", :email => Faker::Internet.email, 
                                              :active => 1, :role => 1
                                              })
    @agent5 = add_agent_to_account(@account, {:name => "agent5", :email => Faker::Internet.email, 
                                              :active => 1, :role => 1
                                              })
    @group1 = create_group_with_agents(@account, agent_list: [@agent3.user_id, @agent4.user_id]);
    @group2 = create_group_with_agents(@account, agent_list: [@agent4.user_id, @agent5.user_id]);
    @agent3.allow_availability_toggle?.should be true
    @agent4.allow_availability_toggle?.should be true
    @agent5.allow_availability_toggle?.should be true
    @group2.ticket_assign_type = 1
    @group2.toggle_availability = true
    @group2.save
    @group2.reload
    @agent4.allow_availability_toggle?.should be true
    @group2.toggle_availability = false
    @group2.save
    @group2.reload
    @group1.ticket_assign_type = 1
    @group1.toggle_availability = false
    @group1.save
    @group1.reload
    @agent4.allow_availability_toggle?.should be false
    @agent3.allow_availability_toggle?.should be false
    @group1.toggle_availability = true
    @group1.save
    @group1.reload
    @agent4.allow_availability_toggle?.should be false
    @agent3.allow_availability_toggle?.should be true
    @group2.toggle_availability = true
    @group2.save
    @group2.reload
    @agent4.allow_availability_toggle?.should be true
    @agent5.allow_availability_toggle?.should be true
  end

  it "should not allow toggle availability if round robin feature is disabled" do
    @account.reload
    @agent6 = add_agent_to_account(@account, {:name => "agent6", :email => Faker::Internet.email, 
                                              :active => 1, :role => 1
                                              })
    @group3 = create_group_with_agents(@account, agent_list: [@agent6.user_id]);
    @account.features.round_robin.delete if @account.features?(:round_robin)
    @agent6.account.reload
    @group3.ticket_assign_type = 1
    @group3.toggle_availability = true;
    @group3.save!
    @group3.reload
    @account.agents.find(@agent6.id).toggle_availability?.should be false
  end

  it "should allow toggle availability only if round robin feature is enabled" do
    @account.reload
    @agent7 = add_agent_to_account(@account, {:name => "agent7", :email => Faker::Internet.email, 
                                              :active => 1, :role => 1
                                              })
    @group4 = create_group_with_agents(@account, agent_list: [@agent7.user_id]);
    @account.features.send(:round_robin).create
    @agent7.account.reload
    @group4.ticket_assign_type = 1
    @group4.toggle_availability = true;
    @group4.save!
    @group4.reload
    @account.agents.find(@agent7.id).toggle_availability?.should be true
  end
end


