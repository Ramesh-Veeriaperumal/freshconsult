require 'spec_helper'

describe GroupsController do
	integrate_views
	setup :activate_authlogic
	self.use_transactional_fixtures = false

	before(:all) do
		@now = (Time.now.to_f*1000).to_i
		@user_1 = add_test_agent(@account)
		@test_group = create_group(@account, {:name => "Spec Testing Grp Helper"})
		@calendar = Factory.build(:business_calendars,:name=> "Grp business_calendar", :description=>Faker::Lorem.sentence(2),:account_id=>@account.id)
		@calendar.save(false)
	end

	before(:each) do
		log_in(@agent)
	end

	after(:all) do
		@test_group.destroy
		@calendar.destroy
	end

	it "should go to the Groups index page" do
		get :index
		response.body.should =~ /Product Management/
		response.should be_success
	end

	it "should create a new Group" do
		get :new
		response.body.should =~ /Automatic Ticket Assignment/
		response.should be_success
		post :create, { :group => { :name => "Spec Testing Grp #{@now}", :description => Faker::Lorem.paragraph, :business_calendar => @calendar.id,
									:agent_list => "#{@agent.id}", :ticket_assign_type=> 1, :assign_time => "1800", :escalate_to => @user_1.id
									}
		}
		@account.groups.find_by_name("Spec Testing Grp #{@now}").should_not be_nil
	end

	it "should not create a Group without the name" do
		post :create, { :group => { :name => "", :description => Faker::Lorem.paragraph, :business_calendar => @calendar.id,
									:agent_list => "#{@agent.id},#{@user_1.id}", :ticket_assign_type=> 1,
									:assign_time => "1800", :escalate_to => @agent.id
									}
		}
		response.body.should =~ /Name can&#39;t be blank/
	end

	it "should edit the Group" do
		get :edit, :id => @test_group.id
		response.body.should =~ /"#{@test_group.name}"/
	end

	it "should show the Group" do
		get :show, :id => @test_group.id
		response.body.should =~ /redirected/
	end

	it "should update the Group" do
		put :update, {
			:id => @test_group.id,
			:group => {:name => "Updated: Spec Testing Grp #{@now}",
				:description => Faker::Lorem.paragraph, :business_calendar => @calendar.id,
				:added_list => "",
				:removed_list => "", 
				:ticket_assign_type=> 0,
				:assign_time => "2500", :escalate_to => @agent.id
			}
		}
		@test_group.reload
		@test_group.name.should eql("Updated: Spec Testing Grp #{@now}")
		@test_group.escalate_to.should eql(@agent.id)
		@test_group.ticket_assign_type.should eql 0
	end

	it "should add agents to the group" do
		put :update, {
			:id => @test_group.id,
			:group => {:name => "Updated: Spec Testing Grp #{@now}",
				:description => Faker::Lorem.paragraph, :business_calendar => @calendar.id,
				:added_list => "#{@agent.id} , #{@user_1.id}",
				:removed_list => "",
				:ticket_assign_type=> 0,
				:assign_time => "2500", :escalate_to => @agent.id
			}
		}
		@test_group.reload
		@test_group.name.should eql("Updated: Spec Testing Grp #{@now}")
		@test_group.escalate_to.should eql(@agent.id)
		@test_group.ticket_assign_type.should eql 0
		agent_list = [ @agent.id, @user_1.id ]
		agents_in_group = @test_group.agent_groups.map { |agent| agent.user_id }
		(agent_list.sort == agents_in_group.sort).should be_true
	end

	it "should remove agents from the group" do
		put :update, {
			:id => @test_group.id,
			:group => {:name => "Updated: Spec Testing Grp #{@now}",
				:description => Faker::Lorem.paragraph, :business_calendar => @calendar.id,
				:added_list => "",
				:removed_list => "#{@agent.id}",
				:ticket_assign_type=> 0,
				:assign_time => "2500", :escalate_to => @agent.id
			}
		}
		@test_group.reload
		@test_group.name.should eql("Updated: Spec Testing Grp #{@now}")
		@test_group.escalate_to.should eql(@agent.id)
		@test_group.ticket_assign_type.should eql 0
		agents_in_group = @test_group.agent_groups.map { |agent| agent.user_id }
		agents_in_group.include?(@agent.id).should be_false
	end

	it "should not update the Group without a name" do
		put :update, {
			:id => @test_group.id,
			:group => {:name => "",
				:description => "Updated Description: Spec Testing Grp", :business_calendar => @calendar.id,
				:added_list => "#{@user_1.id}",
				:removed_list => "",
				:ticket_assign_type=> 0,
				:assign_time => "2500", :escalate_to => @agent.id
			}
		}
		@test_group.reload
		@test_group.name.should eql("Updated: Spec Testing Grp #{@now}")
		@test_group.name.should_not eql ""
		@test_group.escalate_to.should eql(@agent.id)
		@test_group.description.should_not eql "Updated Description: Spec Testing Grp"
	end

	it "should delete a Group" do
		group = @account.groups.find_by_name("Spec Testing Grp #{@now}")
		delete :destroy, :id => group.id
		@account.groups.find_by_id(group.id).should be_nil
	end
end
