require 'spec_helper'

RSpec.describe GroupsController do
	self.use_transactional_fixtures = false

	before(:each) do
		request.host = @account.full_domain
		http_login(@agent)
	end

	before(:all) do
		@test_group = create_group(@account, {:name => "Spec Testing Grp Helper"})
		@calendar = FactoryGirl.build(:business_calendars,:name=> "Grp business_calendar", :description=>Faker::Lorem.sentence(2),:account_id=>@account.id)
		@calendar.save(:validate => false)
	end

	after(:all) do
		@test_group.destroy
		@calendar.destroy
	end

	it "should not create a Group without the name" do
		post :create, { :group => { :name => "", :description => Faker::Lorem.paragraph, :business_calendar => @calendar.id, 
									:agent_list => "#{@agent.id}", :ticket_assign_type=> 1, :assign_time => "1800", :escalate_to => @agent.id
									},
						:format => 'json'
		}
		name_blank?(response).should be true
	end

	it "should not update the Group without a name" do
		description = Faker::Lorem.paragraph
		put :update, {
			:id => @test_group.id,
			:group => {:name => "",
				:description => description, 
				:business_calendar => @calendar.id,
				:agent_list => "#{@agent.id}",
				:ticket_assign_type=> 0,
				:assign_time => "2500", 
				:escalate_to => @agent.id
			},
			:format => 'json'
		}
		name_blank?(response).should be true
		@test_group.reload
		@test_group.name.should eql("Spec Testing Grp Helper")
		@test_group.name.should_not eql ""
		@test_group.description.should_not eql(description)
	end

		def name_blank?(response)
			json = parse_json(response)
			json["errors"].join(" ").should =~ /Name can't be blank/
		end
end