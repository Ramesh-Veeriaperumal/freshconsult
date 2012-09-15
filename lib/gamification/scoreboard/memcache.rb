module Gamification::Scoreboard::Memcache

	include MemcacheKeys

	def memcache_local_key(account=Account.current)
		MEMCACHE_LEADERBOARD_MINILIST % {:account_id => account.id,:agent_type => agent_type}
	end

	def memcache_app_key(item)
		"views/#{memcache_local_key(item.account)}"
	end

	def memcache_delete(item)
		begin	
			$memcache.delete(memcache_app_key(item))
		rescue Exception => e
			NewRelic::Agent.notice_error(e)
		end	
	end

	def agent_type
		(User.current && User.current.can_view_all_tickets?) ? "UNRESTRICTED" :  "RESTRICTED"
	end	
	
end