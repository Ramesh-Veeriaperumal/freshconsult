module Gamification::Scoreboard::Memcache

	include MemcacheKeys

	def memcache_local_key(account=current_account)
		MEMCACHE_LEADERBOARD_MINILIST % {:account_id => account.id }
	end

	def memcache_app_key(score)
		"views/#{memcache_local_key(score.account)}"
	end

	def memcache_delete(score)
		begin	
			$memcache.delete(memcache_app_key(score))
		rescue Exception => e
			NewRelic::Agent.notice_error(e)
		end	
	end
	
end