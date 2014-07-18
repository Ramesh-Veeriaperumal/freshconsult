require 'spec_helper'

describe Helpdesk::CommonsController do
	integrate_views
	setup :activate_authlogic
	self.use_transactional_fixtures = false

	before(:all) do
		@test_group = create_group(@account, {:name => "Testing group_agents"})
		agents_group = Factory.build(:agent_group, :user_id => @agent.id, :group_id => @test_group.id)
		agents_group.save(false)
	end

	before(:each) do
		log_in(@agent)
	end

	it "should list all agents added in that groups" do
		post :group_agents, :id => @test_group.id
		response.body.should =~ /#{@agent.id}/
		response.body.should =~ /#{@agent.name}/
		response.should be_success
	end

	it "should list all agents added in that groups(format - mobile)" do
		post :group_agents, :id => @test_group.id, :format => 'mobile'
		response.body.should =~ /#{@agent.id}/
		response.body.should =~ /#{@agent.name}/
		response.body.should =~ /#{@agent.email}/
		response.should be_success
	end
end