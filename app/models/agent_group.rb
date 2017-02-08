class AgentGroup < ActiveRecord::Base
  self.primary_key = :id
 
  include Cache::Memcache::Helpdesk::Filters::CustomTicketFilter
  include RoundRobinCapping::Methods
  include MemcacheKeys

  belongs_to_account
  belongs_to :user
  belongs_to :group

  validates_presence_of :user

  attr_accessible :group_id, :user_id

  after_commit :reset_internal_agent, on: :destroy

  after_commit ->(obj) { obj.clear_cache_agent_group; obj.remove_from_chatgroup_channel }, on: :destroy
  after_commit ->(obj) { obj.clear_cache_agent_group; obj.add_to_chatgroup_channel }, on: :create
  after_commit :clear_agent_groups_cache
  after_commit :add_to_group_capping, on: :create, :if => :capping_enabled?
  after_commit :remove_from_group_capping, on: :destroy, :if => :capping_enabled?
  after_commit :sync_skill_based_user_queues


  scope :available_agents,
        :joins => %(INNER JOIN agents on 
          agents.user_id = agent_groups.user_id and
          agents.account_id = agent_groups.account_id),
        :select => "agents.user_id",
        :conditions => ["agents.available = ?",true]

  def sync_skill_based_user_queues
    if account.skill_based_round_robin_enabled? && group.skill_based_round_robin_enabled? && 
        (user.agent.nil? || user.agent.available?)#user.agent.nil? - hack for agent destroy
      args = {:action => _action, :user_id => user_id, :group_id => group_id}
      args[:skill_ids] = user.skills.pluck(:id) if _action == :destroy
      SBRR::Config::AgentGroup.perform_async args
    end
  end

  def _action
    [:create, :update, :destroy].find{ |action| transaction_include_action? action }
  end

  def remove_from_chatgroup_channel
    LivechatWorker.perform_async({:worker_method =>"group_channel",
                                  :siteId => account.chat_setting.site_id,
                                  :agent_id => user_id, :group_id => group_id,
                                  :type => 'remove'}) if Account.current.freshchat_routing_enabled?
  end

  def add_to_chatgroup_channel
    LivechatWorker.perform_async({:worker_method =>"group_channel",
                                  :siteId => account.chat_setting.site_id,
                                  :agent_id => user_id, :group_id => group_id,
                                  :type => 'add'}) if Account.current.freshchat_routing_enabled?
  end

  def clear_agent_groups_cache
    MemcacheKeys.memcache_delete(ACCOUNT_AGENT_GROUPS % { account_id: Account.current.id })
  end

  private

    def capping_enabled?
      self.group.round_robin_capping_enabled?
    end

    def add_to_group_capping
      if user.agent.available?
        self.group.add_agent_to_group_capping(self.user_id)
        Groups::AssignTickets.perform_async({:agent_id => user.agent.id, :group_id => group_id})
      end
    end
    
    def remove_from_group_capping
      self.group.remove_agent_from_group_capping(self.user_id)
    end

    def reset_internal_agent
      #Reset internal agent only if an agent is removed from a group.
      if Account.current.features?(:shared_ownership) and agent_removed_from_group?
        reason = {:remove_agent => [self.user_id, self.group.name]}
        Helpdesk::ResetInternalAgent.perform_async({:internal_group_id => self.group_id, :internal_agent_id => self.user_id, :reason => reason})
      end
    end

    def agent_removed_from_group?
      Account.current.groups.exists?(self.group_id) and Account.current.technicians.exists?(self.user_id)
    end

end
