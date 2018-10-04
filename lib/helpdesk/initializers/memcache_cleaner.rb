module MemcacheCleaner
  extend ActiveSupport::Concern

  include MemcacheKeys

  included do
    after_commit :clean_memcache_data
  end

  def clean_memcache_data
    begin
      if defined? self.cache_keys_to_delete
        acc_id_hash = { account_id: self.account_id }
        self.cache_keys_to_delete.each do |key|
          MemcacheKeys.delete_from_cache key % acc_id_hash
        end
      end
    rescue StandardError => e
      Rails.logger.info "Exception while clean response cache : #{e.message} : #{e.backtrace}"
    end
  end
  
  module ClassMethods
    def clear_memcache(keys)
      self.send :define_method, "cache_keys_to_delete" do
        keys || []
      end
    end
  end
  
end

ActiveRecord::Base.send :include, MemcacheCleaner
