module MemcacheCleaner
  extend ActiveSupport::Concern

  include MemcacheKeys

  included do
    after_commit :clean_memcache
  end

  def clean_memcache
    acc_id_hash = { :account_id => self.account_id }
    # we can have func to get keys to generate dynamic keys
    self.class::DELETE_CACHE_KEYS.each do |key|
      MemcacheKeys.delete_from_cache key % acc_id_hash
    end
  end
end