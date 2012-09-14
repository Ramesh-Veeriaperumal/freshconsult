module Helpdesk::LeaderboardHelper
		
	include Gamification::Scoreboard::Memcache

	def link_to_agent user
		return(link_to user.name, user) if current_user && current_user.can_view_all_tickets?
		user.name
	end

end
