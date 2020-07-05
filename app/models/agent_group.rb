class AgentGroup < ActiveRecord::Base
  self.primary_key = :id
 
  include Cache::Memcache::Helpdesk::Filters::CustomTicketFilter
  include RoundRobinCapping::Methods
  include MemcacheKeys
  include DataVersioning::Model

  VERSION_MEMBER_KEY = 'AGENTS_GROUPS_LIST'.freeze

  concerned_with :presenter

  belongs_to_account
  belongs_to :user
  belongs_to :group

  validates_presence_of :user

  attr_accessor :multiple_agents_added_to_group
  attr_accessible :group_id, :user_id, :multiple_agents_added_to_group, :write_access

  after_commit :reset_internal_agent, on: :destroy

  after_commit ->(obj) { obj.clear_cache_agent_group; obj.remove_from_chatgroup_channel }, on: :destroy
  after_commit ->(obj) { obj.clear_cache_agent_group; obj.add_to_chatgroup_channel }, on: :create
  after_commit :clear_agent_groups_cache
  after_commit :clear_agent_groups_hash_cache
  after_commit :add_to_group_capping, on: :create, :if => :capping_enabled?
  after_commit :remove_from_group_capping, on: :destroy, :if => :capping_enabled?
  after_commit :sync_skill_based_user_queues
  before_save :create_model_changes, on: :update
  before_destroy :save_deleted_agent_group_info

  publishable

  scope :available_agents,
        :joins => %(INNER JOIN agents on 
          agents.user_id = agent_groups.user_id and
          agents.account_id = agent_groups.account_id),
        :select => "agents.user_id",
        :conditions => ["agents.available = ?",true]

  scope :with_groupids, lambda { |group_ids|
    { :conditions => ["group_id in (?)", group_ids] }
  }

  scope :permissible_user, lambda { |group_ids, user_id|
    { :conditions => ["user_id = ? AND group_id in (?)", user_id, group_ids] }
  }

  scope :write_access_only, -> { where('write_access = ?', true) }

  swindle :basic_info,
          attrs: %i[user_id group_id]

  def sync_skill_based_user_queues
    if account.skill_based_round_robin_enabled? && group.skill_based_round_robin_enabled? && 
        (user.agent.nil? || user.agent.available?)#user.agent.nil? - hack for agent destroy
      args = {:action => _action, :user_id => user_id, :group_id => group_id, :multiple_agents_added_to_group => multiple_agents_added_to_group}
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
    MemcacheKeys.delete_from_cache(format(ACCOUNT_AGENT_GROUPS, account_id: Account.current.id))
    MemcacheKeys.delete_from_cache(format(ACCOUNT_AGENT_GROUPS_OPTAR, account_id: Account.current.id))
    MemcacheKeys.delete_from_cache(format(ACCOUNT_AGENT_GROUPS_ONLY_IDS, account_id: Account.current.id))
    MemcacheKeys.delete_from_cache(format(ALL_AGENT_GROUPS_CACHE_FOR_AN_AGENT, account_id: Account.current.id, user_id: user_id)) if user_id.present?
    MemcacheKeys.delete_from_cache(format(AGENT_CONTRIBUTION_ACCESS_GROUPS, account_id: Account.current.id, user_id: user_id)) if user_id.present?
  end

  def clear_agent_groups_hash_cache
    MemcacheKeys.delete_from_cache(format(ACCOUNT_AGENT_GROUPS_HASH, account_id: Account.current.id))
    MemcacheKeys.delete_from_cache(format(ACCOUNT_AGENT_GROUPS_ONLY_IDS, account_id: Account.current.id))
    delete_value_from_cache(format(ACCOUNT_WRITE_ACCESS_AGENT_GROUPS_HASH, account_id: Account.current.id))
  end

  private

    def save_deleted_agent_group_info
      @deleted_model_info = central_publish_payload
    end

    def create_model_changes
      @model_changes = self.changes.to_hash
      @model_changes.symbolize_keys!
    end

    def capping_enabled?
      self.group.lbrr_enabled?
    end

    def add_to_group_capping
      Groups::SyncAndAssignTickets.perform_async({ agent_id: user.agent.id, group_id: group_id })
    end
    
    def remove_from_group_capping
      self.group.remove_agent_from_group_capping(self.user_id)
    end

    def reset_internal_agent
      #Reset internal agent only if an agent is removed from a group.
      if Account.current.shared_ownership_enabled? and agent_removed_from_group?
        reason = {:remove_agent => [self.user_id, self.group.name]}
        Helpdesk::ResetInternalAgent.perform_async({:internal_group_id => self.group_id, :internal_agent_id => self.user_id, :reason => reason})
      end
    end

    def agent_removed_from_group?
      Account.current.groups.exists?(self.group_id) and Account.current.technicians.exists?(self.user_id)
    end

end
