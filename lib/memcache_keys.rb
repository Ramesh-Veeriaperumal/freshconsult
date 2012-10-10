module MemcacheKeys
	
  LEADERBOARD_MINILIST = "HELPDESK_LEADERBOARD_MINILIST:%{agent_type}:%{account_id}"

  AVAILABLE_QUEST_LIST = "AVAILABLE_QUEST_LIST:%{user_id}:%{account_id}"

  USER_TICKET_FILTERS = "v1/TICKET_VIEWS:%{user_id}:%{account_id}"

  ACCOUNT_TICKET_TYPES = "v1/ACCOUNT_TICKET_TYPES:%{account_id}"

  ACCOUNT_AGENTS = "v1/ACCOUNT_AGENTS:%{account_id}"

  ACCOUNT_GROUPS = "v1/ACCOUNT_GROUPS:%{account_id}"

  ACCOUNT_TAGS = "v1/ACCOUNT_TAGS:%{account_id}"

  ACCOUNT_CUSTOMERS = "v1/ACCOUNT_CUSTOMERS:%{account_id}"

  ACCOUNT_ONHOLD_CLOSED_STATUSES = "v1/ACCOUNT_ONHOLD_CLOSED_STATUSES:%{account_id}"

  ACCOUNT_STATUSES = "v1/ACCOUNT_STATUSES:%{account_id}"

  class << self
		def memcache_local_key(key, account=Account.current, user=User.current)
			key % {:account_id => account.id, :agent_type => agent_type(user) , :user_id => user.id}
		end

		def memcache_view_key(key, account=Account.current, user=User.current)
			"views/#{memcache_local_key(key, account, user)}"
		end

		def memcache_delete(key, account=Account.current, user=User.current)
			begin	
				$memcache.delete(memcache_view_key(key, account, user))
			rescue Exception => e
				NewRelic::Agent.notice_error(e)
			end	
		end

		def agent_type(user) #pass user as argument
			user.can_view_all_tickets? ? "UNRESTRICTED" :  "RESTRICTED"
		end

		def get_from_cache(key)
			begin
				$memcache.get(key)
			rescue Exception => e
				NewRelic::Agent.notice_error(e)
			end
		end

		def cache(key,value)
			begin
				$memcache.set(key, value)
			rescue Exception => e
				NewRelic::Agent.notice_error(e)
			end
		end

		def delete_from_cache(key)
			begin
				$memcache.delete(key)
			rescue Exception => e
				NewRelic::Agent.notice_error(e)
			end
		end

		def fetch(key, &block)
			cache_data = get_from_cache(key)
			unless cache_data
				Rails.logger.debug "Cache hit missed :::::: #{key}"
				cache_data = block.call
				#MemcacheKeys.cache(key, cache_data)
				cache(key, (cache_data = block.call))
			end

			cache_data
		end
	end
end