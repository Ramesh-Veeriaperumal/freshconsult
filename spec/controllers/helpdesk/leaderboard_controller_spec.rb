require 'spec_helper'

include Gamification::Scoreboard::Constants

describe Helpdesk::LeaderboardController do
	integrate_views
	setup :activate_authlogic
	self.use_transactional_fixtures = false

	before(:all) do
		@agent_1 = add_test_agent(@account)
		@agent_2 = add_test_agent(@account)
		@group = create_group(@account, {:name => "Leaderboard"})

		# create Quest
		quest_data = {:value=>"10", :date=>"6"}
		@soln_quest = create_article_quest(@account, quest_data)
		@tkt_quest_1 = create_ticket_quest(@account, quest_data)
		@tkt_quest_2 = create_ticket_quest(@account, quest_data = {:value=>"5", :date=>"4"})

		# create Support_score
		create_support_score( { :user_id => @agent_1.id, :score_trigger=> SOLUTION_QUEST,:score => 200, 
								:scorable_id=>@soln_quest.id,:scorable_type=> "Quest" } )
		create_support_score( { :user_id => @agent_2.id,:score_trigger=> FIRST_CALL_RESOLUTION,:score => 400,
								:scorable_id=>@tkt_quest_1.id,:scorable_type=> "Helpdesk::Ticket" } )
	end

	before(:each) do
		log_in(@agent)
		@start_date = Time.zone.now.beginning_of_month
		@end_date = Time.zone.now
	end

	it "should display Agent Leaderboard" do
		get :agents
		response.body.should =~ /Agent Leaderboard/
		response.body.should =~ /Most Valuable Player/
		response.body.should =~ /Sharpshooter/
		response.body.should =~ /#{@agent_1.name}/
		response.body.should =~ /#{@agent_2.name}/
		response.should be_success
	end 

	it "should display Leaderboard Mini_list - 1" do
		get :mini_list
		response.body.should =~ /Leaderboard/
		response.body.should =~ /Most Valuable Player/
		response.body.should =~ /Sharpshooter/
		response.body.should_not =~ /Speed Racer/
		response.body.should_not =~ /Customer Wow Champion/

		#check if agent_2 is a Most Valuable Player
		user_support_score.limit(1).first.user_id.should eql @agent_2.id

		#check if agent_2 is a Sharpshooter
		user_support_score.first_call.limit(1).first.user_id.should eql @agent_2.id

		#check if  Mini_list Leaderboard Speed Racer is empty
		user_support_score.fast.should be_empty

		#check if  Mini_list Leaderboard Customer Wow Champion is empty
		user_support_score.customer_champion.should be_empty
		response.should be_success
	end

	it "should display Group Leaderboard" do
		create_support_score( { :user_id => @agent_1.id,:group_id => @group.id,:score_trigger=> FAST_RESOLUTION,:score => 700,
								:scorable_id=>@tkt_quest_2.id,:scorable_type=> "Helpdesk::Ticket" } )
		
		get :groups
		response.body.should =~ /Group Leaderboard/
		response.body.should =~ /Speed Racer/
		response.body.should =~ /#{@group.name}/

		#check if group is a Most Valuable Player in Groups Leaderboard
		group_support_score.limit(1).first.group_id.should eql @group.id

		#check if group is a Speed Racer in Groups Leaderboard
		group_support_score.fast.limit(1).first.user_id.should eql @agent_1.id

		#check if Groups Leaderboard Sharpshooter is empty
		group_support_score.first_call.should be_empty

		#check if Groups Leaderboard Customer Wow Champion is empty
		group_support_score.customer_champion.should be_empty
		response.should be_success
	end

	it "should display Leaderboard Mini_list" do
		create_support_score( { :user_id => @agent_2.id,:score_trigger=> HAPPY_CUSTOMER,:score => 250,:scorable_id=>@tkt_quest_2.id,
								:scorable_type=> "Helpdesk::Ticket" } )

		get :mini_list
		response.body.should =~ /Leaderboard/
		response.body.should =~ /Sharpshooter/
		response.body.should =~ /Customer Wow Champion/

		#check if agent_1 is a Most Valuable Player
		user_support_score.limit(1).first.user_id.should eql @agent_1.id

		#check if agent_1 is a Speed Racer
		user_support_score.fast.limit(1).first.user_id.should eql @agent_1.id

		#check if agent_2 is a Sharpshooter
		user_support_score.first_call.limit(1).first.user_id.should eql @agent_2.id

		#check if agent_2 is a Customer Wow Champion
		user_support_score.customer_champion.limit(1).first.user_id.should eql @agent_2.id
		response.should be_success
	end

	def user_support_score
		@account.support_scores.by_performance.user_score.created_at_inside(@start_date,@end_date)
	end

	def group_support_score
		@account.support_scores.by_performance.group_score.created_at_inside(@start_date,@end_date)
	end

	def create_support_score params = {}
		new_ss = Factory.build( :support_score, :user_id => params[:user_id],
												:score_trigger=> params[:score_trigger],
												:group_id => params[:group_id] || nil,
												:score => params[:score],
												:scorable_id=> params[:scorable_id],
												:scorable_type=> params[:scorable_type])
		new_ss.save(false)
	end
end