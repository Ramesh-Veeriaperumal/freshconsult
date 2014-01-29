class AgentGroup < ActiveRecord::Base
 
  include Cache::Memcache::Helpdesk::Filters::CustomTicketFilter

  belongs_to_account
  belongs_to :user
  belongs_to :group

  validates_presence_of :user_id

  after_commit_on_destroy :clear_cache
  after_commit_on_create :clear_cache
end