class AgentGroup < ActiveRecord::Base
  self.primary_key = :id
 
  include Cache::Memcache::Helpdesk::Filters::CustomTicketFilter
  include RoundRobinCapping::Methods

  belongs_to_account
  belongs_to :user
  belongs_to :group

  validates_presence_of :user

  attr_accessible :group_id, :user_id

  after_commit ->(obj) { obj.clear_cache_agent_group; obj.remove_from_chatgroup_channel }, on: :destroy
  after_commit ->(obj) { obj.clear_cache_agent_group; obj.add_to_chatgroup_channel }, on: :create
  after_commit :add_to_group_capping, on: :create, :if => :capping_enabled?
  after_commit :remove_from_group_capping, on: :destroy, :if => :capping_enabled?

  scope :available_agents,
        :joins => %(INNER JOIN agents on 
          agents.user_id = agent_groups.user_id and
          agents.account_id = agent_groups.account_id),
        :select => "agents.user_id",
        :conditions => ["agents.available = ?",true]

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
end
