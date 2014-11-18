require 'spec_helper'

RSpec.describe GroupsController do
	self.use_transactional_fixtures = false

	before(:all) do
		@now = (Time.now.to_f*1000).to_i
		@user_1 = add_test_agent(@account)
		@test_group = create_group(@account, {:name => "Spec Testing Grp Helper"})
		@calendar = FactoryGirl.build(:business_calendars,:name=> "Grp business_calendar", :description=>Faker::Lorem.sentence(2),:account_id=>@account.id)
		@calendar.save(:validate => false)
	end

	before(:each) do
		request.host = @account.full_domain
		http_login(@agent)
	end

	after(:all) do
		@test_group.destroy
		@calendar.destroy
	end

	it "should create a new Group" do
		post :create, { :group => { :name => "Spec Testing Grp - json", :description => Faker::Lorem.paragraph, :business_calendar => @calendar.id,
        :agent_list => "#{@agent.id}", :ticket_assign_type=> 1, :assign_time => "1800", :escalate_to => @user_1.id
      },
      :format => 'json'
		}
		result = parse_json(response)
		expected = (response.status == 201) && (compare(result["group"].keys,APIHelper::GROUP_ATTRIBS,{}).empty?) && 
					(compare(result["group"]["agents"].first.keys,APIHelper::CONTACT_ATTRIBS,{}).empty?)
		expected.should be(true)
		@account.groups.find_by_name("Spec Testing Grp - json").should_not be_nil
	end

	it "should update the group" do
		put :update, {
			:id => @test_group.id,
			:group => {:name => "Updated: Spec Testing Grp #{@now}",
				:description => Faker::Lorem.paragraph, :business_calendar => @calendar.id,
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
		(agent_list.sort == agents_in_group.sort).should be true
	end

	it "should add new agents to the group" do
		put :update, {
			:id => @test_group.id,
			:group => {:name => "Updated: Spec Testing Grp #{@now}",
				:description => Faker::Lorem.paragraph, :business_calendar => @calendar.id,
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
		(agent_list.sort == agents_in_group.sort).should be true
	end

	it "should go to the Groups index page" do
		get :index, :format => 'json'
		result = parse_json(response)
		expected = (response.status == 200) && (compare(result.first["group"].keys,APIHelper::GROUP_ATTRIBS,{}).empty?) && 
					(compare(result.last["group"]["agents"].first.keys,APIHelper::CONTACT_ATTRIBS,{}).empty?)
		expected.should be(true)
	end

	it "should delete a Group" do
		group = @account.groups.find_by_name("Spec Testing Grp - json")
		delete :destroy, :id => group.id, :format => 'json'
		@account.groups.find_by_id(group.id).should be_nil
	end
end