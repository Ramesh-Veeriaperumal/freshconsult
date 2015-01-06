require 'spec_helper'

include Gamification::Scoreboard::Constants

RSpec.describe Helpdesk::LeaderboardController do
	setup :activate_authlogic
	self.use_transactional_fixtures = false

	before(:all) do
		@account.support_scores.destroy_all
		@limit = 1

		# Create Agent
		@agent_1 = add_test_agent(@account)
		@agent_2 = add_test_agent(@account)

		# Create Group
		@group_1 = create_group(@account, {:name => "Group 1 Leaderboard"})
		@group_2 = create_group(@account, {:name => "Group 2 Leaderboard"})

		# create Quest
		quest_data = {:value=>"10", :date=>"6"}
		@soln_quest = create_article_quest(@account, quest_data)
		@tkt_quest_1 = create_ticket_quest(@account, quest_data)
		@tkt_quest_2 = create_ticket_quest(@account, quest_data = {:value=>"5", :date=>"4"})

		# create Support_score
		create_support_score( { :user_id => @agent_1.id, :score_trigger=> SOLUTION_QUEST,:score => 200,
								:scorable_id=>@soln_quest.id,:scorable_type=> "Quest" } )
		create_support_score( { :user_id => @agent_2.id,:group_id => @group_1.id,:score_trigger=> FIRST_CALL_RESOLUTION,:score => 400,
								:scorable_id=>@tkt_quest_1.id,:scorable_type=> "Helpdesk::Ticket" } )
	end

	before(:each) do
		log_in(@agent)
		@start_date = Time.zone.now.beginning_of_month
		@end_date = Time.zone.now
	end

	it "should display Agent Leaderboard" do
		get :agents
		response.body.should =~ /Agent/
		response.body.should =~ /Most Valuable Player/
		response.body.should =~ /Sharpshooter/
		response.body.should =~ /#{ERB::Util.html_escape(@agent_1.name)}/
		response.body.should =~ /#{ERB::Util.html_escape(@agent_2.name)}/
		response.should be_success
	end

	it "should display Leaderboard Mini_list" do
		get :mini_list
		response.body.should =~ /Leaderboard/
		response.body.should =~ /Most Valuable Player/
		response.body.should =~ /Sharpshooter/
		response.body.should =~ /#{ERB::Util.html_escape(@agent_2.name)}/
		response.body.should_not =~ /#{ERB::Util.html_escape(@agent_1.name)}/
		response.body.should_not =~ /Speed Racer/
		response.body.should_not =~ /Customer Wow Champion/

		#check if agent_2 is a Most Valuable Player
		assigns[:mvp_scorecard].first.user_id.should eql @agent_2.id
		user_support_score.limit(@limit).first.user_id.should eql @agent_2.id

		#check if agent_2 is a Sharpshooter
		assigns[:first_call_scorecard].first.user_id.should eql @agent_2.id
		user_support_score.first_call.limit(@limit).first.user_id.should eql @agent_2.id

		#check if  Mini_list Leaderboard Speed Racer is empty
		assigns[:fast_scorecard].should be_empty
		user_support_score.fast.all.should be_empty

		#check if  Mini_list Leaderboard Customer Wow Champion is empty
		assigns[:customer_champion_scorecard].should be_empty
		user_support_score.customer_champion.all.should be_empty
		response.should be_success
	end

	it "should display Group Leaderboard" do
		get :groups
		response.body.should =~ /Group/
		response.body.should =~ /Speed Racer/
		response.body.should =~ /#{@group_1.name}/
		response.body.should_not =~ /#{@group_2.name}/

		#check if group is a Most Valuable Player in Groups Leaderboard
		assigns[:mvp_scorecard].first.group_id.should eql @group_1.id
		group_support_score.limit(@limit).first.group_id.should eql @group_1.id

		#check if group is a Speed Racer is empty
		assigns[:fast_scorecard].should be_empty
		group_support_score.fast.all.should be_empty

		#check if Groups Leaderboard Sharpshooter is empty
		assigns[:first_call_scorecard].first.group_id.should eql @group_1.id
		group_support_score.first_call.limit(@limit).first.group_id.should eql @group_1.id

		#check if Groups Leaderboard Customer Wow Champion is empty
		assigns[:customer_champion_scorecard].should be_empty
		group_support_score.customer_champion.all.should be_empty
		response.should be_success
	end

	it "should display Group Leaderboard with new scores" do
		create_support_score( { :user_id => @agent_1.id,:group_id => @group_2.id,:score_trigger=> FAST_RESOLUTION,:score => 700,
								:scorable_id=>@tkt_quest_2.id,:scorable_type=> "Helpdesk::Ticket" } )

		get :groups
		response.body.should =~ /Group/
		response.body.should =~ /Speed Racer/
		response.body.should =~ /#{@group_1.name}/
		response.body.should =~ /#{@group_2.name}/

		#check if group is a Most Valuable Player in Groups Leaderboard
		assigns[:mvp_scorecard].first.group_id.should eql @group_2.id
		group_support_score.limit(@limit).first.group_id.should eql @group_2.id

		#check if group is a Speed Racer in Groups Leaderboard
		assigns[:fast_scorecard].first.group_id.should eql @group_2.id
		group_support_score.fast.limit(@limit).first.group_id.should eql @group_2.id

		#check if Groups Leaderboard Sharpshooter is empty
		assigns[:first_call_scorecard].first.group_id.should eql @group_1.id
		group_support_score.first_call.limit(@limit).first.group_id.should eql @group_1.id

		#check if Groups Leaderboard Customer Wow Champion is empty
		assigns[:customer_champion_scorecard].should be_empty
		group_support_score.customer_champion.all.should be_empty
		response.should be_success
	end

	it "should display Leaderboard Mini_list with new scores" do
		create_support_score( { :user_id => @agent_2.id,:score_trigger=> HAPPY_CUSTOMER,:score => 250,:scorable_id=>@tkt_quest_2.id,
								:scorable_type=> "Helpdesk::Ticket" } )

		get :mini_list
		response.body.should =~ /Leaderboard/
		response.body.should =~ /Sharpshooter/
		response.body.should =~ /Customer Wow Champion/
		response.body.should =~ /#{ERB::Util.html_escape @agent_1.name}/
		response.body.should =~ /#{ERB::Util.html_escape @agent_2.name}/

		#check if agent_1 is a Most Valuable Player
		assigns[:mvp_scorecard].first.user_id.should eql @agent_1.id
		user_support_score.limit(@limit).first.user_id.should eql @agent_1.id

		#check if agent_1 is a Speed Racer
		assigns[:fast_scorecard].first.user_id.should eql @agent_1.id
		user_support_score.fast.limit(@limit).first.user_id.should eql @agent_1.id

		#check if agent_2 is a Sharpshooter
		assigns[:first_call_scorecard].first.user_id.should eql @agent_2.id
		user_support_score.first_call.limit(@limit).first.user_id.should eql @agent_2.id

		#check if agent_2 is a Customer Wow Champion
		assigns[:customer_champion_scorecard].first.user_id.should eql @agent_2.id
		user_support_score.customer_champion.limit(@limit).first.user_id.should eql @agent_2.id
		response.should be_success
	end

	it "should display scores of users belonging to a particular group" do
		quest_data = {:value=>"10", :date=>"6"}
		@tkt_quest_3 = create_ticket_quest(@account, quest_data)
		create_support_score( { :user_id => @agent_2.id,:group_id => @group_1.id,:score_trigger=> FAST_RESOLUTION,:score => 700,
								:scorable_id=>@tkt_quest_2.id,:scorable_type=> "Helpdesk::Ticket" } )
		get :group_agents, :id => @group_1.id
		response.body.should =~ /Most Valuable Player/
		response.body.should =~ /Sharpshooter/
		response.body.should =~ /Speed Racer/
		response.body.should =~ /Customer Wow Champion/
		response.body.should =~ /#{@group_1.name}/
		response.should be_success
	end

	it "should show agents within a particular date range" do
		get :agents, :date_range => "current_month"
		response.body.should =~ /Most Valuable Player/
		response.body.should =~ /Sharpshooter/
		response.should be_success
	end

	it "should show empty when no scores are available for a particular date range" do
		get :agents, :date_range => "2_months_ago"
		@start_date = Time.zone.parse(2.month.ago.beginning_of_month.to_s)
		@end_date = Time.zone.parse(2.month.ago.end_of_month.to_s)
		assigns[:mvp_scorecard].should be_empty
		user_support_score.all.should be_empty
		assigns[:fast_scorecard].should be_empty
		user_support_score.fast.all.should be_empty
		assigns[:first_call_scorecard].should be_empty
		user_support_score.first_call.all.should be_empty
		assigns[:customer_champion_scorecard].should be_empty
		user_support_score.customer_champion.all.should be_empty
	end

	def user_support_score
		@account.support_scores.by_performance.user_score(user_scope_params).created_at_inside(@start_date,@end_date)
	end

	def group_agent_support_score
		@account.support_scores.by_performance.user_score(group_agent_scope_params).created_at_inside(@start_date,@end_date)
	end

	def group_support_score
		@account.support_scores.by_performance.group_score.created_at_inside(@start_date, @end_date)
	end

	def create_support_score params = {}
		new_ss = FactoryGirl.build( :support_score, :user_id => params[:user_id],
												:score_trigger=> params[:score_trigger],
												:group_id => params[:group_id] || nil,
												:score => params[:score],
												:scorable_id=> params[:scorable_id],
												:scorable_type=> params[:scorable_type])
		new_ss.save(:validate => false)
	end

	def user_scope_params
		{ :conditions => ["user_id is not null"] }
	end

	def group_agent_scope_params
		{ :conditions => ["support_scores.group_id = ?", @group.id] }
	end
end