class PodShardCondition < ActiveRecord::Base

  not_sharded

  after_update :clear_cache
  after_destroy :clear_cache
  
  def self.fetch_details
    current_shard = Thread.current[:shard_selection].shard
    return if current_shard.blank?
    
    key = POD_SHARD_ACCOUNT_MAPPING % { :pod_info => PodConfig['CURRENT_POD'], :shard_name => current_shard }
    ::MemcacheKeys.fetch(key) { 
      self.find_by_pod_info_and_shard_name(PodConfig['CURRENT_POD'], current_shard)
    }
  end

  private
    def clear_cache
      unless shard_name_was.blank?
        key = POD_SHARD_ACCOUNT_MAPPING % { :pod_info => PodConfig['CURRENT_POD'], :shard_name => shard_name_was }
        ::MemcacheKeys.delete_from_cache key
      end
    end

end