require 'spec_helper'

describe Group do
	include Redis::RedisKeys
	include Redis::OthersRedis

	before(:all) do 
    	@group = create_group(@account,{:ticket_assign_type => 1, :name =>  Faker::Name.name})
 	end

 	it "should belong to an account" do
 		@group.account_id.should_not be_nil
 	end

 	it "should have default as ticket assign type for groups unless specified" do
 		@group1 = create_group(@account,{:name =>  Faker::Name.name})
 		@group1.ticket_assign_type.should == Group::TICKET_ASSIGN_TYPE[:default]

 	end

 	it "should not return next available agent for non-round robin groups" do 
 		@group4 = create_group(@account,{:ticket_assign_type => 0,:name =>  Faker::Name.name})
 		@group4.next_available_agent.should be_nil
 	end

 	it "should return next available agent for round robin groups if available" do
 		
 		@group_6 = create_group(@account,{:ticket_assign_type => Group::TICKET_ASSIGN_TYPE[:round_robin],
	    								:name =>  Faker::Name.name})
 		@ag1 = add_agent_to_account(@account, { :name => "testing", :email => Faker::Internet.email, 
                                            :active => 1, :available => true})
 		#creating an unavailable agent
 		@ag2 = add_agent_to_account(@account, { :name => "testing", :email => Faker::Internet.email, 
                                            :active => 1,:available => false})

 		Resque.inline = true
 		@group_6.agents << @ag1.user
 		@group_6.agents << @ag2.user
 		user_ids = @group_6.agent_groups.available_agents.map(&:user_id)
 		value = set_others_redis_lpush(@group_6.round_robin_key, user_ids) if user_ids.any?
 		@group_6.next_available_agent.should_not be_nil
 		Resque.inline = false

 	end

 	it "should say whether its eligible for round robin or not"  do
	    @group5 = create_group(@account,{:ticket_assign_type => Group::TICKET_ASSIGN_TYPE[:default],
	    								:name =>  Faker::Name.name})
	    @group5.round_robin_enabled?.should == false

	    @group6 = create_group(@account,{:ticket_assign_type => Group::TICKET_ASSIGN_TYPE[:round_robin],
	    								:name =>  Faker::Name.name})
	    @group6.round_robin_enabled?.should be true

	end

	it "should create a list if group is created with round robon" do
		@group6 = create_group(@account,{:ticket_assign_type => Group::TICKET_ASSIGN_TYPE[:round_robin],
	    								:name =>  Faker::Name.name})
		
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
	    								:name =>  Faker::Name.name})
		value = get_others_redis_list(@group7.round_robin_key)
		value.should be_empty
	end

	it "should create a list if group is updated with round_robin" do
		@group8 = create_group(@account,{:name =>  Faker::Name.name})
		@group8.ticket_assign_type = Group::TICKET_ASSIGN_TYPE[:round_robin]
		@group.save
		@ag1 = add_agent_to_account(@account, { :name => "testing", :email => Faker::Internet.email, 
                                            :active => 1,:group_id => @group8.id})

		value = get_others_redis_list(@group8.round_robin_key)
		value.should_not be_nil
	end

	it "should not have a list if group is updated without round_robin" do
		@group9 = create_group(@account,{:ticket_assign_type => Group::TICKET_ASSIGN_TYPE[:round_robin],
	    								:name =>  Faker::Name.name})
		@group9.ticket_assign_type = Group::TICKET_ASSIGN_TYPE[:default]
		@group.save
		value = get_others_redis_list(@group9.round_robin_key)
		value.should be_empty
	end

	it "should delete the round robin list after group deletion" do
		@group9 = create_group(@account,{:ticket_assign_type => Group::TICKET_ASSIGN_TYPE[:round_robin],
	    								:name =>  Faker::Name.name})

		key = @group9.round_robin_key
		value = get_others_redis_list(key)
		value.should_not be_nil

		@group.destroy
		value = get_others_redis_list(key)
		value.should be_empty
	end

	it "should delete the round robin list after group is updated with round_robin turned off" do
		@group9 = create_group(@account,{:ticket_assign_type => Group::TICKET_ASSIGN_TYPE[:round_robin],
	    								:name =>  Faker::Name.name})

		key = @group9.round_robin_key
		value = get_others_redis_list(key)
		value.should_not be_nil

		@group9.ticket_assign_type = Group::TICKET_ASSIGN_TYPE[:default]
		@group.save
		
		value = get_others_redis_list(key)
		value.should be_empty
	end

 end