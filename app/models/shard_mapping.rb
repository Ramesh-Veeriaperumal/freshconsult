class ShardMapping < ActiveRecord::Base
  set_primary_key "account_id"
  not_sharded

  include MemcacheKeys

  STATUS_CODE = {:partial => 206, :ok => 200, :not_found => 404}

  has_many :domains,:class_name => 'DomainMapping',:dependent => :destroy,:foreign_key => :account_id

  after_update :clear_cache
  after_destroy :clear_cache


 def self.lookup(shard_key)
   shard = is_numeric?(shard_key) ? fetch_by_account_id(shard_key) : fetch_by_domain(shard_key)
   shard.shard_name  if shard
 end

 def self.fetch_by_domain(domain)
   return if domain.blank?
   key = SHARD_BY_DOMAIN % { :domain => domain }
   MemcacheKeys.fetch(key) { 
    shard = DomainMapping.find_by_domain(domain)
    shard if shard
  }
 end
    
 def self.fetch_by_account_id(account_id)
   return if account_id.blank?
   key = SHARD_BY_ACCOUNT_ID % { :account_id => account_id }
   MemcacheKeys.fetch(key) { self.find_by_account_id(account_id) }
 end

 def self.is_numeric?(str) #Need to move to shard
    true if Float(str) rescue false
 end

 def self.latest_shard
 	"shard_1" #probably fetch it from Redis or config 
 end

 def clear_cache
    key = SHARD_BY_ACCOUNT_ID % { :account_id => account_id }
    MemcacheKeys.delete_from_cache key
  end

end