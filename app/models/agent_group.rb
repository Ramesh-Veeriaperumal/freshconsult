class AgentGroup < ActiveRecord::Base
 
  include Cache::Memcache::Helpdesk::Filters::CustomTicketFilter

  belongs_to_account
  belongs_to :user
  belongs_to :group

  validates_presence_of :user_id

  named_scope :available_agents,
        :joins => %(INNER JOIN agents on 
          agents.user_id = agent_groups.user_id and
          agents.account_id = agent_groups.account_id),
		:select => "agents.user_id",
        :conditions => ["agents.available = ?",true]

  after_commit_on_destroy :clear_cache_agent_group
  after_commit_on_create :clear_cache_agent_group

end