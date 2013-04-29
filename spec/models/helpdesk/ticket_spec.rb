require 'spec_helper'

describe Helpdesk::Ticket do

  before(:all) do
    clear_data
    @account = create_test_account
    setup_data
    @new_agent = add_agent_to_account(@account, {:name => "testing", :email => "unit@testing.com", 
                                        :token => "xtoQaHDQ7TtTLQ5OKt9", :active => 1, :role => 4,
                                        :group_id => @group.id})
    

    @new_ticket = create_ticket({:status => 2, :display_id => 10}, @group)
    @another_ticket = create_ticket({:status => 2, :display_id => 11}, @group)
  end

  before(:each) do
    @ticket.responder_id = nil
    @ticket.save(false)
    @new_ticket.responder_id = nil
    @new_ticket.save(false)
  end


  def setup_data
    @group = create_group(@account,{:ticket_assign_type => 1, :name =>  "dummy group"})
    @group.ticket_assign_type = 1
    @group.save!

    @agent = add_agent_to_account(@account, {:name => "testing2", :email => "unit2@testing.com", 
                                        :token => "xtoQaHDQ7TtTLQ3OKt9", :active => 1, :role => 1
                                        })
    @agent.available = 1
    @agent.save!

    ag_grp = AgentGroup.new(:user_id => @agent.user_id , :account_id =>  @account.id, :group_id => @group.id)
    ag_grp.save!

    @ticket = create_ticket({:status => 2, :display_id =>9}, @group)
    @ticket.group_id = @group.id
    @ticket.save(false)
  end

  it "should be assigning tickets to agents in round robin" do
    @agent2 = add_agent_to_account(@account, {:name => "testing", :email => "ticket@testing.com", 
                                        :token => "xtoPaHDQ7TtTLQ5OKt9", :active => 1, :role => 4,
                                        :group_id => @group.id})

    @agent3 = add_agent_to_account(@account, {:name => "testing", :email => "ticket1@testing.com", 
                                        :token => "xtoPaHDQ7TtTLQ4OKt9", :active => 1, :role => 4,
                                        :group_id => @group.id})

    @group.ticket_assign_type.should == Group::TICKET_ASSIGN_TYPE[:round_robin]
    #created 2 more agents. so totally 3 agents and 3 tickets.
    @ticket.assign_tickets_to_agents
    @new_ticket.assign_tickets_to_agents
    @another_ticket.assign_tickets_to_agents
    #the assigned agents id should be different
    @ticket.responder_id.should_not == @new_ticket.responder_id
    @ticket.responder_id.should_not == @another_ticket.responder_id
  end


  it "should not be assigned to agent if no agents are available" do
    Agent.any_instance.stubs(:available?).returns(false)
    @agent.available?.should be_false
    @ticket.assign_tickets_to_agents
    @ticket.responder_id.should be_nil
  end

  it "should not be assigned to agents if there is no group " do
    @ticket.group = nil
    @ticket.save!
    @ticket.assign_tickets_to_agents.should be_nil
  end

  it "should not be assigned to agents for non-round robin groups" do
    @group.ticket_assign_type = Group::TICKET_ASSIGN_TYPE[:default]
    @group.save!
    @ticket.assign_tickets_to_agents.should be_nil
  end

  it "should not be assigned to an agent if not available" do
    #making an agent unavailable
    @agent.available = 0
    @agent.save!
    @ticket.assign_tickets_to_agents
    @new_ticket.assign_tickets_to_agents
    @another_ticket.assign_tickets_to_agents
    @ticket.responder_id.should_not == @agent.user_id
    @another_ticket.responder_id.should_not == @agent.user_id
    @new_ticket.responder_id.should_not == @agent.user_id
  end

  it "should not be reassigned to other agent if already assigned to an agent" do
    @ticket.assign_tickets_to_agents
    responder_id = @ticket.responder_id
    @ticket.assign_tickets_to_agents
    #reassigning shouldn't change the agent
    responder_id.should == @ticket.responder_id
  end

 

  


end

