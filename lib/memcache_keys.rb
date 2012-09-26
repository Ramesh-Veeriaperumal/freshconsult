module MemcacheKeys
	
  MEMCACHE_LEADERBOARD_MINILIST = "HELPDESK_LEADERBOARD_MINILIST:%{agent_type}:%{account_id}"

  MEMCACHE_AVAILABLE_QUEST_LIST = "MEMCACHE_AVAILABLE_QUEST_LIST:%{user_id}:%{account_id}"

  def memcache_local_key(key,account=Account.current,user=User.current)
		key % {:account_id => account.id,:agent_type => agent_type, :user_id => user.id}
	end

	def memcache_app_key(key,account=Account.current,user=User.current)
		"views/#{memcache_local_key(key,account,user)}"
	end

	def memcache_delete(key,account=Account.current,user=User.current)
		begin	
			$memcache.delete(memcache_app_key(key,account,user))
		rescue Exception => e
			NewRelic::Agent.notice_error(e)
		end	
	end

	def agent_type
		(User.current && User.current.can_view_all_tickets?) ? "UNRESTRICTED" :  "RESTRICTED"
	end

end