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

  after_commit_on_destroy :clear_cache_agent_group, :remove_from_chatgroup_channel
  after_commit_on_create :clear_cache_agent_group, :add_to_chatgroup_channel

  def remove_from_chatgroup_channel
    Resque.enqueue(Workers::Freshchat, {:worker_method =>"group_channel",
                                        :siteId => account.chat_setting.display_id,
                                        :agent_id => user_id, :group_id => group_id,
                                        :type => 'remove'}) if account.freshchat_routing_enabled?
  end

  def add_to_chatgroup_channel
    Resque.enqueue(Workers::Freshchat, {:worker_method =>"group_channel",
                                        :siteId => account.chat_setting.display_id,
                                        :agent_id => user_id, :group_id => group_id,
                                        :type => 'add'}) if account.freshchat_routing_enabled?
  end

end