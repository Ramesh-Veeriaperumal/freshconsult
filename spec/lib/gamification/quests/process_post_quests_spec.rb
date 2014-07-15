require 'spec_helper'

describe Gamification::Quests::ProcessPostQuests do
	self.use_transactional_fixtures = false

	before(:all) do
		@account.quests.answer_forum_quests.each {|quest| quest.destroy}
		@user = add_test_agent(@account)
		@category = create_test_category
		@forum_1 = create_test_forum(@category)
		@forum_2 = create_test_forum(@category)
		@topic_1 = create_test_topic(@forum_1)
		@topic_2 = create_test_topic(@forum_2)
	end

	after(:each) do
		Resque.inline = false
	end

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
			@quests = [@new_quest_1.id,@new_quest_2.id]
		end

		it "should not achieve quests when filter_data is not satisfied" do
			Resque.inline = true
			post = create_test_post(@topic_2,@user)
			unachieved_response(@quests)
		end

		it "should achieve the quests when filter conditions and quest_data is satisfied" do
			Resque.inline = true
			post = create_test_post(@topic_1,@user)
			achieved_response(@quests)
		end
	end

	context "For quest achievement with or_filters conditions" do

		before(:all) do
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

		it "should not achieve quests when filter_data is not satisfied" do
			Resque.inline = true
			post = create_test_post(@topic_2,@user)
			@account.quests.find(@new_quest_3.id).achieved_quests.first.should be_nil
			unachieved_response([@new_quest_3.id])
		end

		it "should achieve the quests when filter conditions and quest_data is satisfied" do
			Resque.inline = true
			post = create_test_post(@topic_1,@user)
			@account.quests.find(@new_quest_3.id).achieved_quests.first.should_not be_nil
			achieved_response([@new_quest_3.id])
		end
	end

		def unachieved_response quests
			quests.each { |id| @account.quests.find(id).achieved_quests.first.should be_nil }
		end

		def achieved_response quests
			quests.each { |id| @account.quests.find(id).achieved_quests.first.should_not be_nil }
		end
end
