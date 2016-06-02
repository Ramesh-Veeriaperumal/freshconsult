class AgentGroup < ActiveRecord::Base
  self.primary_key = :id
 
  include Cache::Memcache::Helpdesk::Filters::CustomTicketFilter

  belongs_to_account
  belongs_to :user
  belongs_to :group

  validates_presence_of :user

  attr_accessible :group_id, :user_id

  after_commit ->(obj) { obj.clear_cache_agent_group; obj.remove_from_chatgroup_channel }, on: :destroy
  after_commit ->(obj) { obj.clear_cache_agent_group; obj.add_to_chatgroup_channel }, on: :create
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
  
end