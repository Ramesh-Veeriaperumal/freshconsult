class PopulateShardMapping < ActiveRecord::Migration
  shard :none

  def self.up
  	execute("insert into shard_mappings(account_id,shard_name,status) select id,'shard_1',200 from accounts")
  end

  def self.down
  	execute("delete from shard_mappings")
  end
end
