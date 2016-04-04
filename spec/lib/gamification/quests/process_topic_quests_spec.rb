require 'spec_helper'

RSpec.describe Gamification::Quests::ProcessTopicQuests do
	self.use_transactional_fixtures = false

	before(:all) do
		@account.quests.create_forum_quests.each {|quest| quest.destroy}
		@user = add_test_agent(@account)
		@category = create_test_category
		@forum_1 = create_test_forum(@category)
		@forum_2 = create_test_forum(@category)
	end

	after(:each) do
		Resque.inline = false
	end	

	# after(:all) do
	# 	@user.destroy
	# end

	context "For quest achievement with or_filters conditions" do

		before(:all) do
			Resque.inline = false
			quest_data = {:value=>"2", :date=>"2"}
			@new_quest_1 = create_forum_quest(@account, "create", quest_data)
			filter_data = {
				:actual_data=>[ {:name=>"forum_id", :operator=>"is", :value=>"#{@forum_2.id}"}, 
								{:name=>"forum_id", :operator=>"is", :value=>"#{@forum_1.id}"}],
				:and_filters=>[], 
				:or_filters => {:forum_id=>[{:name=>"forum_id", :operator=>"is", :value=>"#{@forum_2.id}"}, 
											{:name=>"forum_id", :operator=>"is", :value=>"#{@forum_1.id}"}]
								}
			}
			quest_data = {:value=>"2", :date=>"4"}
			@new_quest_2 = create_forum_quest(@account, "create", quest_data, filter_data)
			@quests = [@new_quest_1,@new_quest_2]
		end

		before(:each) do
			@exiting_pts = total_points
		end

		it "should not achieve quests when quest_data is not satisfied" do
			Resque.inline = true
			topic = create_test_topic(@forum_1,@user)
			unachieved_response(@quests,@exiting_pts)
		end

		it "should achieve the quests when filter conditions and quest_data is satisfied" do
			Resque.inline = true
			2.times do
				topic = create_test_topic(@forum_2,@user)
			end
			achieved_response(@quests,@exiting_pts)
		end
	end

	context "For quest achievement with and_filters conditions" do

		before(:all) do
			filter_data = {
				:actual_data=>[{:name=>"user_votes", :operator=>"greater_than", :value=>"3"}],
				:and_filters=>[{:name=>"user_votes", :operator=>"greater_than", :value=>"3"}], 
				:or_filters => []
			}
			quest_data = {:value=>"1"}
			@quest_1 = create_forum_quest(@account, "create", quest_data, filter_data)
			filter_data = {
				:actual_data=>[ {:name=>"forum_id", :operator=>"is", :value=>"#{@forum_1.id}"}, 
								{:name=>"user_votes", :operator=>"greater_than", :value=>"5"} ],
				:and_filters=>[ {:name=>"forum_id", :operator=>"is", :value=>"#{@forum_1.id}"}, 
								{:name=>"user_votes", :operator=>"greater_than", :value=>"5"} ], 
				:or_filters => []
			}
			quest_data = {:value=>"2"}
			@quest_2 = create_forum_quest(@account, "create", quest_data, filter_data)
			@quest = [@quest_1,@quest_2]
		end

		before(:each) do
			@exiting_pts = total_points
		end

		it "should not achieve the quest when user_votes is less than the filter value" do
			topic = create_test_topic(@forum_1,@user)
			Resque.inline = true
			topic.user_votes = 2
			topic.save
			unachieved_response(@quest,@exiting_pts)
		end

		it "should achieve the quests when 2 topics is created in forum_1 and contains more than 5 user_votes" do
			2.times do
				Resque.inline = false
				topic = create_test_topic(@forum_1,@user)
				Resque.inline = true
				topic.user_votes = 7
				topic.save
			end
			achieved_response(@quest,@exiting_pts)
		end
	end

		def unachieved_response quests,exiting_pts
			exiting_pts = 0 if exiting_pts.nil?
			quests.each { |quest| 

				@user.reload
				@account.quests.find(quest.id).achieved_quests.first.should be_nil 
				
				quest.support_scores.should be_empty

				@user.achieved_quests.find_by_quest_id(quest.id).should be_nil

				total_points.should eql(exiting_pts)
			}
		end

		def total_points
			@user.reload
			@user.agent.points.to_i
		end

		def achieved_response quests,exiting_pts
			exiting_pts = 0 if exiting_pts.nil?
			quest_points = 0
			quests.each { |quest|

				@user.reload
				@account.quests.find(quest.id).achieved_quests.first.should_not be_nil 

				quest.support_scores.reload
				quest.support_scores.should_not be_empty
				quest.support_scores.first.score.should eql(quest.points)

				@user.achieved_quests.find_by_quest_id(quest.id).should_not be_nil

				sb_level = @account.scoreboard_levels.level_for_score(total_points).first
				@user.agent.scoreboard_level_id.should eql(sb_level.id) if sb_level
				quest_points += quest.points
			}
			bonus_pts = total_points - exiting_pts
			bonus_pts.should eql(quest_points)
		end
end