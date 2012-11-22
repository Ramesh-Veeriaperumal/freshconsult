module Helpdesk::QuestsHelper
		
	include MemcacheKeys

	def get_memcache_key
		MemcacheKeys.memcache_local_key(AVAILABLE_QUEST_LIST)
	end

	def load_available_quests(limit=2)
		@quests ||= get_available_quests
	end

	private
		def get_available_quests
			current_account.quests.available(current_user).find(:all, :limit => 2)
		end

end
