require 'spec_helper'

RSpec.describe Gamification::Quests::ProcessPostQuests do
	self.use_transactional_fixtures = false

	before(:all) do
		before_all_call
	end

	after(:each) do
		Resque.inline = false
	end

	# after(:all) do
	# 	@user.destroy
	# end

	context "For quest achievement with quest_data and and_filters conditions" do

		before(:all) do
			Resque.inline = false
			filter_data = {
				:actual_data=>[{:name=>"forum_id", :operator=>"is", :value=>"#{@forum_1.id}"}],
				:and_filters=>[{:name=>"forum_id", :operator=>"is", :value=>"#{@forum_1.id}"}], 
				:or_filters => []
			}
			quest_data = {:value=>"1", :date=>"4"}
			@new_quest_1 = create_forum_quest(@account, "answer", quest_data, filter_data)
			quest_data = {:value=>"2", :date=>"2"}
			@new_quest_2 = create_forum_quest(@account, "answer", quest_data)
			@quests = [@new_quest_1,@new_quest_2]
		end

		before(:each) do
			@exiting_pts = total_points
		end

		it "should not achieve quests when filter_data is not satisfied" do
			Resque.inline = true
			post = create_test_post(@topic_2,@user)
			unachieved_response(@quests,@exiting_pts)
		end

		it "should achieve the quests when filter conditions and quest_data is satisfied" do
			Resque.inline = true
			post = create_test_post(@topic_1,@user)
			achieved_response(@quests,@exiting_pts)
		end
	end

	context "For quest achievement with or_filters conditions" do

		before(:all) do
      before_all_call
      
			Resque.inline = false
			filter_data = {
				:actual_data=> [{:name=>"forum_id", :operator=>"is", :value=>"#{@forum_2.id}"}, 
								{:name=>"forum_id", :operator=>"is", :value=>"#{@forum_1.id}"}], 
				:and_filters=>[], 
				:or_filters=>{"forum_id"=> [{:name=>"forum_id", :operator=>"is", :value=>"#{@forum_2.id}"}, 
											{:name=>"forum_id", :operator=>"is", :value=>"#{@forum_1.id}"}]
								}
						}
			quest_data = {:value=>"3", :date=>"5"}
			@new_quest_3 = create_forum_quest(@account, "answer", quest_data, filter_data)
			post = create_test_post(@topic_1,@user)
		end

		before(:each) do
			@exiting_pts = total_points
		end

		it "should not achieve quests when filter_data is not satisfied" do
      count = @account.quests.find(@new_quest_3.id).achieved_quests.count
			Resque.inline = true
			post = create_test_post(@topic_2,@user)
      @account.quests.find(@new_quest_3.id).achieved_quests.count.should eql(count)
			unachieved_response([@new_quest_3],@exiting_pts)
		end

		it "should achieve the quests when filter conditions and quest_data is satisfied" do
			Resque.inline = true
			post = create_test_post(@topic_1,@user)
			@account.quests.find(@new_quest_3.id).achieved_quests.first.should_not be_nil
			achieved_response([@new_quest_3],@exiting_pts)
		end
	end

		def unachieved_response quests,exiting_pts
			exiting_pts = 0 if exiting_pts.nil?
			quests.each { |quest| 

				@user.reload
				@account.quests.find(quest.id).achieved_quests.first.should be_nil 
				
				quest.support_scores.should be_empty

				@user.achieved_quests.find_by_quest_id(quest.id).to_i.should eql(exiting_pts)

				total_points.should eql(0)
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
    
    def before_all_call
      @account.quests.answer_forum_quests.each {|quest| quest.destroy}
      @user = add_test_agent(@account)
      @category = create_test_category
      @forum_1 = create_test_forum(@category)
      @forum_2 = create_test_forum(@category)
      @topic_1 = create_test_topic(@forum_1)
      @topic_2 = create_test_topic(@forum_2)
    end
end
