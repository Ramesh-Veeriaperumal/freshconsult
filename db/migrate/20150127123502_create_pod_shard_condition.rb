class CreatePodShardCondition < ActiveRecord::Migration
  shard :none

  def self.up
    create_table :pod_shard_conditions do |t|
      t.string  :pod_info, :null => false
      t.string  :shard_name, :null => false
      t.string  :query_type, :null => false
      t.text  :accounts, :null => false
    end
    add_index :pod_shard_conditions, [:pod_info, :shard_name], :unique => true
  end

  def self.down
    drop_table :pod_shard_conditions
  end
end
