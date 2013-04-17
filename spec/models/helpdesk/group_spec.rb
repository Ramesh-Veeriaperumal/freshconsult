require 'spec_helper'

describe Group do
	before(:all) do 
    	@account = create_test_account
    	@group = create_group(@account,{:ticket_assign_type => 1, :name =>  "dummy group"})

 	end

 	it "should belong to an account" do
 		@group.account_id.should_not be_nil
 	end

 	it "should have default as ticket assign type for groups unless specified" do
 		@group1 = create_group(@account,{:name =>  "dummy group1"})
 		@group1.ticket_assign_type.should == Group::TICKET_ASSIGN_TYPE[:default]

 	end

 	it "should not return next available agent for non-round robin groups" do 
 		@group4 = create_group(@account,{:ticket_assign_type => 0,:name =>  "dummy group4"})
 		@group4.next_available_agent.should be_nil
 	end

 	it "should return next available agent for round robin groups if available" do
 		@ag1 = add_agent_to_account(@account, {:name => "testing", :email => "unit10@testing.com", 
                                        :token => "xtoQaHEQ7TtTLQ5OKt9", :active => 1, :role => 4,
                                        :group_id => @group.id})
 		#creating an unavailable agent
 		@ag2 = add_agent_to_account(@account, {:name => "testing", :email => "unit11@testing.com", 
                                        :token => "xtoQaADQ7TtTLQ5OKt9", :active => 1, :role => 4,
                                        :group_id => @group.id, :available => 0})

 		@group.next_available_agent.should == @ag1
 		#next available agent should not be the one created as unavailable.
 		@group.next_available_agent.should_not == @ag2

 	end

 	it "should say whether its eligible for round robin or not"  do
	    @group5 = create_group(@account,{:ticket_assign_type => Group::TICKET_ASSIGN_TYPE[:default],
	    								:name =>  "dummy group5"})
	    @group5.round_robin_eligible?.should == false

	    @group6 = create_group(@account,{:ticket_assign_type => Group::TICKET_ASSIGN_TYPE[:round_robin],
	    								:name =>  "dummy group6"})
	    @group6.round_robin_eligible?.should be_true

	end

	

 end