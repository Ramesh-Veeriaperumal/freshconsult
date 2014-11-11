class AgentGroup < ActiveRecord::Base
 
  include Cache::Memcache::Helpdesk::Filters::CustomTicketFilter

  belongs_to_account
  belongs_to :user
  belongs_to :group

  validates_presence_of :user_id

  after_commit ->(obj) { obj.clear_cache_agent_group }, on: :destroy
  after_commit ->(obj) { obj.clear_cache_agent_group }, on: :create

end