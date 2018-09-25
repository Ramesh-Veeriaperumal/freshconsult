module MemcacheCleaner
  extend ActiveSupport::Concern

  include MemcacheKeys

  included do
    after_commit :clean_memcache_data
  end

  def clean_memcache_data
    acc_id_hash = { :account_id => self.account_id }
    if self.class::cache_keys_to_delete.present?
      self.class::cache_keys_to_delete.each do |key|
        MemcacheKeys.delete_from_cache key % acc_id_hash
      end
    end
  end
  module ClassMethods
    def clear_memcache(keys)
      self.class.send :define_method, "cache_keys_to_delete" do
        keys || []
      end
    end
  end
end

ActiveRecord::Base.send :include, MemcacheCleaner
