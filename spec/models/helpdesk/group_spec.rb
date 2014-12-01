require 'spec_helper'
include Redis::RedisKeys
include Redis::OthersRedis

describe Group do
	before(:all) do 
    	@group = create_group(@account,{:ticket_assign_type => 1, :name =>  "dummy group0"})
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
 		@ag1 = add_agent_to_account(@account, { :name => "testing", :email => Faker::Internet.email, 
                                            :active => 1, :role => 4,
                                            :group_id => @group.id})
 		#creating an unavailable agent
 		@ag2 = add_agent_to_account(@account, { :name => "testing", :email => Faker::Internet.email, 
                                            :active => 1, :role => 4,
                                            :group_id => @group.id, :available => 0})

 		@group.next_available_agent.should == @ag1
 		#next available agent should not be the one created as unavailable.
 		@group.next_available_agent.should_not == @ag2

 	end

 	it "should say whether its eligible for round robin or not"  do
	    @group5 = create_group(@account,{:ticket_assign_type => Group::TICKET_ASSIGN_TYPE[:default],
	    								:name =>  "dummy group5"})
	    @group5.round_robin_enabled?.should == false

	    @group6 = create_group(@account,{:ticket_assign_type => Group::TICKET_ASSIGN_TYPE[:round_robin],
	    								:name =>  "dummy group6"})
	    @group6.round_robin_enabled?.should be_true

	end

	it "should create a list if group is created with round robon" do
		@group6 = create_group(@account,{:ticket_assign_type => Group::TICKET_ASSIGN_TYPE[:round_robin],
	    								:name =>  "dummy group6"})
		
		@ag3 = add_agent_to_account(@account, { :name => "testing", :email => Faker::Internet.email, 
                                            :active => 1,
                                            :group_id => @group.id})
 		#creating an unavailable agent
 		@ag4 = add_agent_to_account(@account, { :name => "testing", :email => Faker::Internet.email, 
                                            :active => 1,
                                            :group_id => @group.id, :available => 0})
 		value = get_others_redis_list(@group6.round_robin_key)
		value.should_not be_nil
	end

	it "should not create a list if group is created without round robin" do
		@group7 = create_group(@account,{:ticket_assign_type => Group::TICKET_ASSIGN_TYPE[:default],
	    								:name =>  "dummy group6"})
		value = get_others_redis_list(@group7.round_robin_key)
		value.should be_nil
	end

	it "should create a list if group is updated with round_robin" do
		@group8 = create_group(@account,{:name =>  "dummy group6"})
		@group8.ticket_assign_type = Group::TICKET_ASSIGN_TYPE[:round_robin]
		@group.save
		@ag1 = add_agent_to_account(@account, { :name => "testing", :email => Faker::Internet.email, 
                                            :active => 1,:group_id => @group8.id})

		value = get_others_redis_list(@group8.round_robin_key)
		value.should_not be_nil
	end

	it "should not have a list if group is updated without round_robin" do
		@group9 = create_group(@account,{:ticket_assign_type => Group::TICKET_ASSIGN_TYPE[:round_robin],
	    								:name =>  "dummy group6"})
		@group9.ticket_assign_type = Group::TICKET_ASSIGN_TYPE[:default]
		@group.save
		value = get_others_redis_list(@group9.round_robin_key)
		value.should be_nil
	end

	it "should delete the round robin list after group deletion" do
		@group9 = create_group(@account,{:ticket_assign_type => Group::TICKET_ASSIGN_TYPE[:round_robin],
	    								:name =>  "dummy group6"})

		key = @group9.round_robin_key
		value = get_others_redis_list(key)
		value.should_not be_nil

		@group.destroy
		value = get_others_redis_list(key)
		value.should be_empty
	end

	it "should delete the round robin list after group is updated with round_robin turned off" do
		@group9 = create_group(@account,{:ticket_assign_type => Group::TICKET_ASSIGN_TYPE[:round_robin],
	    								:name =>  "dummy group6"})

		key = @group9.round_robin_key
		value = get_others_redis_list(key)
		value.should_not be_nil

		@group9.ticket_assign_type = Group::TICKET_ASSIGN_TYPE[:default]
		@group.save
		
		value = get_others_redis_list(key)
		value.should be_empty
	end

 end