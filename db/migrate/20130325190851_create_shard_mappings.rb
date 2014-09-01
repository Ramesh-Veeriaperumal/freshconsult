class CreateShardMappings < ActiveRecord::Migration
      
  shard :none    
  
  def self.up
  	create_table :shard_mappings, {:primary_key => :account_id } do |t|
      t.string  :shard_name,:null => false
      t.integer  :status,:default => 200,:null => false 
    end
  end

  def self.down
  	drop_table :shard_mappings
  end
end
