class AgentGroup < ActiveRecord::Base
 
 include RedisKeys
 belongs_to_account
 belongs_to :user
 belongs_to :group
 
 validates_presence_of :user_id
 before_create :set_account_id
 after_commit :clear_redis_for_group


private
	def set_account_id
		self.account_id = user.account_id
	end

	#When an agent group is created, clear redis array of agent ids for that group.
	#This is only for groups that have round robin scheduling.
	def clear_redis_for_group
		return unless group.round_robin_eligible?
		remove_key(GROUP_AGENT_TICKET_ASSIGNMENT % {:account_id => self.account_id, :group_id => self.group_id})
	end

end
