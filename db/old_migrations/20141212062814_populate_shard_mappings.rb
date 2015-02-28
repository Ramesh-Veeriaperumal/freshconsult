class PopulateShardMappings < ActiveRecord::Migration

  shard :all

  def self.up
    execute "update shard_mappings set shard_mappings.pod_info='#{PodConfig['CURRENT_POD']}'"
  end

  def self.down
    execute "update shard_mappings set pod_info = null"
  end

end
