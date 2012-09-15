module Helpdesk::LeaderboardHelper
		
	include Gamification::Scoreboard::Memcache

	def link_to_agent user
		return(link_to user.name, user) if current_user && current_user.can_view_all_tickets?
		user.name
	end	

	def leaderboard
		scoreboard = [[ @mvp_scorecard, :mvp],
				[ @first_call_scorecard, :sharpshooter],
				[ @fast_scorecard, :speed]]
		scoreboard.insert(1, [ @customer_champion_scorecard, :love]) if customer_satisfaction_enabled?
		scoreboard
	end

	def customer_satisfaction_enabled?
		current_account.features?(:surveys, :survey_links)
	end

end
