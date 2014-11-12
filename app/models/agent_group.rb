class AgentGroup < ActiveRecord::Base
 
  include Cache::Memcache::Helpdesk::Filters::CustomTicketFilter

  belongs_to_account
  belongs_to :user
  belongs_to :group

  validates_presence_of :user_id

  after_commit ->(obj) { obj.clear_cache_agent_group }, on: :destroy
  after_commit ->(obj) { obj.clear_cache_agent_group }, on: :create
  # Please keep this one after the ar after_commit callbacks - rails 3
  include ObserverAfterCommitCallbacks
  scope :available_agents,
        :joins => %(INNER JOIN agents on 
          agents.user_id = agent_groups.user_id and
          agents.account_id = agent_groups.account_id),
		:select => "agents.user_id",
        :conditions => ["agents.available = ?",true]

end