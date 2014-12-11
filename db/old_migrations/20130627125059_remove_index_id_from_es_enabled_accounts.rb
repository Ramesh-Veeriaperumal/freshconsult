class RemoveIndexIdFromEsEnabledAccounts < ActiveRecord::Migration
   shard :none
  def self.up
  	remove_column :es_enabled_accounts,:index_id
  end
  

  def self.down
  	add_column :es_enabled_accounts,:index_id, "bigint unsigned"
  end
end
