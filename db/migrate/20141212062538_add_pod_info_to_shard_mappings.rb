class AddPodInfoToShardMappings < ActiveRecord::Migration

  shard :none

  def self.up
    Lhm.change_table :shard_mappings, :atomic_switch => true do |m|
      m.add_column :pod_info, "varchar(255) COLLATE utf8_unicode_ci"
      m.add_column :region, "varchar(255) COLLATE utf8_unicode_ci DEFAULT 'us-east-1' NOT NULL"
    end
  end

  def self.down
    Lhm.change_table :shard_mappings, :atomic_switch => true do |m|
      m.remove_column :pod_info
      m.remove_column :region
    end
  end
end
