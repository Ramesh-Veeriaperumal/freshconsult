
class ShardMapping < ActiveRecord::Base
  
  set_primary_key "account_id"
  not_sharded

  include MemcacheKeys

  STATUS_CODE = {:partial => 206, :ok => 200, :not_found => 404}

  has_many :domains,:class_name => 'DomainMapping',:dependent => :destroy,:foreign_key => :account_id
  has_many :facebook_pages, :class_name => 'FacebookPageMapping', :dependent => :destroy, :foreign_key => :account_id
  has_one :google_domain,:class_name => 'GoogleDomain', :dependent => :destroy, :foreign_key => :account_id

  after_update :clear_cache
  after_destroy :clear_cache


 def self.lookup_with_account_id(shard_key)
   shard =  fetch_by_account_id(shard_key) 
 end

 def self.lookup_with_domain(shard_key)
   shard = fetch_by_domain(shard_key)
 end

 def self.fetch_by_domain(domain)
   return if domain.blank?
   key = SHARD_BY_DOMAIN % { :domain => domain }
   MemcacheKeys.fetch(key) { 
    domain_maping = DomainMapping.find_by_domain(domain)
    domain_maping.shard if domain_maping
  }
 end
    
 def self.fetch_by_account_id(account_id)
   return if account_id.blank?
   key = SHARD_BY_ACCOUNT_ID % { :account_id => account_id }
   MemcacheKeys.fetch(key) { self.find_by_account_id(account_id) }
 end

 def self.latest_shard
  if Rails.env.development? or Rails.env.test? 
    "shard_1"
  else
    AppConfig['latest_shard']
  end
 end

 def ok?
  status == 200
 end

 def clear_cache
    domains.each {|d| d.clear_cache }
    key = SHARD_BY_ACCOUNT_ID % { :account_id => account_id }
    MemcacheKeys.delete_from_cache key
  end

end