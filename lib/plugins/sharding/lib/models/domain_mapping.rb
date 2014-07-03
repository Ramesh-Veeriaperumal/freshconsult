
class DomainMapping < ActiveRecord::Base

	include MemcacheKeys
	not_sharded
    
    validates_uniqueness_of :domain

    after_update :clear_cache
  	after_destroy :clear_cache

	belongs_to :shard, :class_name => 'ShardMapping',:foreign_key => :account_id

	named_scope :main_portal, :conditions => ['portal_id IS NULL']

	def act_as_directory
  end

	def clear_cache
	  key = SHARD_BY_DOMAIN % { :domain => domain }
      MemcacheKeys.delete_from_cache key
	end
end