class DomainMapping < ActiveRecord::Base
	not_sharded
	establish_connection(Rails.configuration.database_configuration[Rails.env])

	include MemcacheKeys
    
    validates_uniqueness_of :domain

    after_update :clear_cache
  	after_destroy :clear_cache

	belongs_to :shard, :class_name => 'ShardMapping',:foreign_key => :account_id

	def clear_cache
	  key = SHARD_BY_DOMAIN % { :domain => domain }
      MemcacheKeys.delete_from_cache key
	end
end