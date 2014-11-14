class WhitelistUser < ActiveRecord::Base

  self.primary_key = :id
	not_sharded

	include Cache::Memcache::WhitelistUser

	attr_accessible :user_id, :account_id

	validates_presence_of :user_id, :account_id

	validates_uniqueness_of :user_id, :scope => :account_id

	validates_numericality_of :user_id, :account_id

	after_commit :clear_whitelist_users_cache

end