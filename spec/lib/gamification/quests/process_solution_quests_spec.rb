require 'spec_helper'

describe Gamification::Quests::ProcessSolutionQuests do
	self.use_transactional_fixtures = false

	before(:all) do
		@account.quests.solution_quests.each {|quest| quest.destroy}
		@user = add_test_agent(@account)
		@test_category = create_category({:name => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", 
										  :is_default => false} )
		@test_folder_1 = create_folder({:name => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", :visibility => 1,
									  :category_id => @test_category.id } )
		@test_folder_2 = create_folder({:name => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", :visibility => 1,
									  :category_id => @test_category.id } )
	end

	after(:each) do
		Resque.inline = false
	end	

	it "should achieve this quest when 3 article is published in a span of 1 week with each article of more than 7 thumbs_up" do
		exiting_pts = 0
		filter_data = {
				:actual_data=>[{:name=>"thumbs_up", :operator=>"greater_than", :value=>"7"}],
				:and_filters=>[{:name=>"thumbs_up", :operator=>"greater_than", :value=>"7"}], 
				:or_filters => []
			}
		quest_data = {:value=>"3", :date=>"4"}
		new_quest = create_article_quest(@account, quest_data, filter_data)
		3.times do
			Resque.inline = false
			test_article = create_article( {:title => "#{Faker::Lorem.sentence(2)}", :description => "#{Faker::Lorem.sentence(3)}", 
											:folder_id => @test_folder_1.id, :user_id => @user.id, :status => "2", :art_type => "1"} )
			Resque.inline = true
			test_article.thumbs_up = 10
			test_article.save
		end
		result(new_quest,exiting_pts)
	end

	it "should achieve this quest when 3 article is published in a span of 2 days in folder_1 or folder_2" do
		exiting_pts = total_points
		filter_data = {
				:actual_data=>[ {:name=>"folder_id", :operator=>"is", :value=>"#{@test_folder_1.id}"}, 
								{:name=>"folder_id", :operator=>"is", :value=>"#{@test_folder_2.id}"} ],
				:and_filters=>[], 
				:or_filters => { "folder_id"=>[ {:name=>"folder_id", :operator=>"is", :value=>"#{@test_folder_1.id}"}, 
												{:name=>"folder_id", :operator=>"is", :value=>"#{@test_folder_2.id}"} ]
								}
			}
		quest_data = {:value=>"3", :date=>"3"}
		new_quest = create_article_quest(@account, quest_data, filter_data)
		Resque.inline = true
		3.times do
			test_article = create_article( {:title => "#{Faker::Lorem.sentence(2)}", :description => "#{Faker::Lorem.sentence(3)}", 
											:folder_id => @test_folder_2.id, :user_id => @user.id, :status => "2", :art_type => "1"} )
		end
		result(new_quest,exiting_pts)
	end

	it "should achieve this quest when 2 article is published in a span of 1 day with more than 3 thumbs_up in folder_2" do
		exiting_pts = total_points
		filter_data = {
				:actual_data=>[ {:name=>"folder_id", :operator=>"is", :value=>"#{@test_folder_2.id}"}, 
								{:name=>"thumbs_up", :operator=>"greater_than", :value=>"3"} ],
				:and_filters=>[ {:name=>"folder_id", :operator=>"is", :value=>"#{@test_folder_2.id}"}, 
								{:name=>"thumbs_up", :operator=>"greater_than", :value=>"3"} ], 
				:or_filters => []
			}
		quest_data = {:value=>"2", :date=>"2"}
		new_quest = create_article_quest(@account, quest_data, filter_data)
		2.times do
			Resque.inline = false
			test_article = create_article( {:title => "#{Faker::Lorem.sentence(2)}", :description => "#{Faker::Lorem.sentence(3)}", 
											:folder_id => @test_folder_2.id, :user_id => @user.id, :status => "2", :art_type => "1"} )
			Resque.inline = true
			test_article.thumbs_up = 4
			test_article.save
		end
		result(new_quest,exiting_pts)
	end

	it "should not achieve this quest when 10 article is not published in a span of 1 day" do
		exiting_pts = total_points
		quest_data = {:value=>"15", :date=>"6"}
		new_quest = create_article_quest(@account, quest_data)
		Resque.inline = true
		test_article = create_article( {:title => "#{Faker::Lorem.sentence(3)}", :description => "#{Faker::Lorem.sentence(3)}", 
										:folder_id => @test_folder_1.id,:user_id => @user.id, :status => "2", :art_type => "1" } )
		
		@user.reload
		@account.quests.find(new_quest.id).achieved_quests.first.should be_nil
		new_quest.support_scores.should be_empty
		@user.achieved_quests.find_by_quest_id(new_quest.id).should be_nil
		bonus_pts = total_points - exiting_pts
		bonus_pts.should_not eql(new_quest.points)
	end

		def total_points
			@user.agent.points
		end

		def result(quest,exiting_pts)
			@user.reload
			@account.quests.find(quest.id).achieved_quests.first.should_not be_nil

			quest.support_scores.should_not be_nil
			quest.support_scores.first.score.should eql(quest.points)

			@user.achieved_quests.find_by_quest_id(quest.id).should_not be_nil

			bonus_pts = total_points - exiting_pts
			bonus_pts.should eql(quest.points)

			sb_level = @account.scoreboard_levels.level_for_score(total_points).first
			@user.agent.scoreboard_level_id.should eql(sb_level.id) if sb_level
		end
end