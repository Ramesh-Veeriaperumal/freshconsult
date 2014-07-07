require 'spec_helper'

describe GroupsController do
	self.use_transactional_fixtures = false
	include APIAuthHelper

	before(:all) do
		@now = (Time.now.to_f*1000).to_i
		@user_1 = add_test_agent(@account)
		@test_group = create_group(@account, {:name => "Spec Testing Grp Helper"})
	end

	before(:each) do
	    request.host = @account.full_domain
	    http_login(@agent)
	end

	after(:all) do
        @test_group.destroy
    end

	it "should go to the Groups index page" do
		get :index, :format => 'json'
		json = parse_json(response)
		json.first['group']['description'] == 'Product Management group'
		response.status.should be_eql("200 OK")
	end

	it "should create a new Group" do
		post :create, { :group => {:name => "Spec Testing Grp - json", :description => Faker::Lorem.paragraph, :business_calendar => 1,
		                           :agent_list => "#{@agent.id}", :ticket_assign_type=> 1, :assign_time => "1800", :escalate_to => @user_1.id},
		                :format => 'json'
		                }
		Group.find_by_name("Spec Testing Grp - json").should_not be_nil
	end

	it "should update the group" do
		put :update, {
			:id => @test_group.id,
			:group => {:name => "Updated: Spec Testing Grp #{@now}",
				:description => Faker::Lorem.paragraph, :business_calendar => 1,
				:agent_list => "#{@agent.id} , #{@user_1.id}",
				:ticket_assign_type=> 0,
		        :assign_time => "2500", :escalate_to => @agent.id
			},
			:format => 'json'
		}
		@test_group.reload
		@test_group.name.should eql("Updated: Spec Testing Grp #{@now}")
		@test_group.escalate_to.should eql(@agent.id)
		@test_group.ticket_assign_type.should eql 0
		agent_list = [ @agent.id, @user_1.id ]
		agents_in_group = @test_group.agent_groups.map { |agent| agent.user_id }
		(agent_list.sort == agents_in_group.sort).should be_true
	end

	it "should add new agents to the group" do
		put :update, {
			:id => @test_group.id,
			:group => {:name => "Updated: Spec Testing Grp #{@now}",
				:description => Faker::Lorem.paragraph, :business_calendar => 1,
				:agent_list => "#{@user_1.id}",
				:ticket_assign_type=> 0,
		        :assign_time => "2500", :escalate_to => @agent.id
			},
			:format => 'json'
		}
		@test_group.reload
		@test_group.name.should eql("Updated: Spec Testing Grp #{@now}")
		@test_group.escalate_to.should eql(@agent.id)
		@test_group.ticket_assign_type.should eql 0
		agent_list = [@user_1.id]
		agents_in_group = @test_group.agent_groups.map { |agent| agent.user_id }
		(agent_list.sort == agents_in_group.sort).should be_true
    end

    it "should delete a Group" do
    	group = Group.find_by_name("Spec Testing Grp - json")
		delete :destroy, :id => group.id, :format => 'json'
		Group.find_by_id(group.id).should be_nil
	end
end